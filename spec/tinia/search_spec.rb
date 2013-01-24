require 'spec_helper'

describe Tinia::Search do

  before(:all) do

    conn = ActiveRecord::Base.connection
    conn.create_table(:mock_classes, :force => true) do |t|
      t.string("name")
      t.timestamps
    end
    
    # TODO: find a better way to stub Rails.
    module Rails
      def self.root; '/'; end
    end
    
    MockClass = Class.new(ActiveRecord::Base) do
      indexed_with_cloud_search do |config|
        config.cloud_search_domain = "mock-class"
      end

      scope :name_like, lambda{|n|
        where("name LIKE ?", n)
      }

    end
    
    MockClass.cloud_search_config.index_fields = {
      'id'     => Tinia::IndexField.new(:name => 'id', :type => 'uint'),
      'name'   => Tinia::IndexField.new(:name => 'name', :type => 'text'),
      'gender' => Tinia::IndexField.new(:name => 'gender', :type => 'literal')
    }
      
  end

  context "#cloud_search" do

    before(:each) do
      AWSCloudSearch::SearchRequest.stubs(:new => search_request)

      MockClass.cloud_search_connection
        .expects(:search)
        .with(search_request)
        .returns(stub({
          :hits => [
            {"id" => 1},
            {"id" => 2}
          ],
          :found => 300,
          :start => 0
        }))
    end

    let(:search_request) do
      search_request = AWSCloudSearch::SearchRequest.new
      search_request.expects(:bq=).with("(and 'my query' type:'MockClass')")
      search_request
    end

    it "should proxy its search request to cloud_search and return
      an Arel-like object" do

      proxy = MockClass.cloud_search("my query")
      proxy.where_values.should eql(
        ["mock_classes.id IN (1,2)"]
      )
    end

    it "should be chainable, maintaining its meta_data" do
      proxy = MockClass.cloud_search("my query").name_like("name")
      proxy.current_page.should eql(1)
      proxy.offset.should eql(0)
    end

    context "Rich Search" do
      let(:search_request) do
        AWSCloudSearch::SearchRequest.new.tap do |req|
          req.expects(:bq=).with(
            "(and (and 'x' other_field:'y') type:'MockClass')"
          )
        end
      end

      it "should allow for a complex query" do
        proxy = MockClass.cloud_search("(and 'x' other_field:'y')")
        proxy.where_values.should eql(
          ["mock_classes.id IN (1,2)"]
        )
      end
    end

    context "#current_page" do

      it "should default to 1" do
        proxy = MockClass.cloud_search("my query")
        proxy.current_page.should eql(1)
      end

      it "should set nil arguments to 1" do
        proxy = MockClass.cloud_search("my query", :page => nil)
        proxy.current_page.should eql(1)
      end

      it "should be able to be set" do
        search_request.expects(:start=).with(80)
        proxy = MockClass.cloud_search("my query", :page => 5)
        proxy.current_page.should eql(5)
      end

    end

    context "#next_page" do

      it "should be one less than the current_page" do
        proxy = MockClass.cloud_search("my query")
        proxy.next_page.should eql 2
      end

    end

    context "#offset" do

      it "should be able to compute its offset" do
        proxy = MockClass.cloud_search("my query", :page => 5)
        proxy.offset.should eql(80)
      end

    end

    context "#previous_page" do

      it "should be one less than the current_page" do
        proxy = MockClass.cloud_search("my query")
        proxy.previous_page.should eql 0
      end

    end

    context "#per_page" do

      it "should default to 20" do
        proxy = MockClass.cloud_search("my query")
        proxy.per_page.should eql(20)
      end

      it "should be able to be set" do
        search_request.expects(:size=).with(50)
        proxy = MockClass.cloud_search("my query", :per_page => 50)
        proxy.per_page.should eql(50)
      end

    end

    context "#total_entries" do
      
      it "should get it from its search_response" do
        proxy = MockClass.cloud_search("my query")
        proxy.total_entries.should eql(300)
      end

    end

    context "#total_pages" do
      
      it "should be the ceiling of its total_entries divided 
        by per_page" do
        proxy = MockClass.cloud_search("my query", :per_page => 7)
        proxy.total_pages.should eql(43)
      end

    end
    
    context "search parameters" do
      
      let(:search_request) do
        search_request = AWSCloudSearch::SearchRequest.new
        search_request
      end
      
      it "should always include the class type in the query" do
        
        proxy = MockClass.cloud_search('my query')
        search_request.bq.should match(/type:'MockClass'/)
        
      end
      
      it "should convert parameter values to their correct type
          in the index" do
          
          proxy = MockClass.cloud_search({:name => 'some name', :id => 1, :gender => 'female'})
          search_request.bq.should eql("(and gender:'female' id:1 name:'some name' type:'MockClass')")
        
      end
      
      it "should allow multiple values for one uint field" do
        proxy = MockClass.cloud_search(:id => [1, 2, 3])
        search_request.bq.should eql("(and (or id:1 id:2 id:3) type:'MockClass')")
      end
      
      it "should allow multiple values for one literal/text field" do
        proxy = MockClass.cloud_search(:gender => ['male', 'female'])
        search_request.bq.should eql("(and (or gender:'male' gender:'female') type:'MockClass')")
      end
      
      it "should allow ranges" do
        proxy = MockClass.cloud_search(:id => 100..200)
        search_request.bq.should eql("(and id:100..200 type:'MockClass')")
      end
      
    end
    
    context "result ordering" do

      it "should be passed in the parameters" do
        proxy = MockClass.cloud_search('my query', :order_by => 'name', :sort_mode => :desc)
        search_request.rank.should eql('-name')
      end

    end
    
  end
  
end
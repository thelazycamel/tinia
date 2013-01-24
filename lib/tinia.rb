require 'aws_cloud_search'
require 'logger'
require 'tinia/connection'
require 'tinia/exceptions'
require 'tinia/index'
require 'tinia/configuration'
require 'tinia/logger'
require 'tinia/query_builder'
require 'tinia/search'

require 'tinia/railtie' if defined?(Rails)

module Tinia
  
  def self.connection(domain = "default")
    @connections ||= {}
    @connections[domain] ||= AWSCloudSearch::CloudSearch.new(domain)
  end

  # activate for ActiveRecord
  def self.activate_active_record!
    ::ActiveRecord::Base.send(:extend, Tinia::ActiveRecord)
  end

  module ActiveRecord

    # activation method for an AR class
    def indexed_with_cloud_search(&block)
      mods = [
        Tinia::Connection,
        Tinia::Index,
        Tinia::Search
      ]
      mods.each do |mod|
        unless self.included_modules.include?(mod)
          self.send(:include, mod) 
        end
      end
      
      self.cloud_search_config = Tinia::Configuration.new(self)
      
      # config block
      yield(self.cloud_search_config) if block_given?
      
      self.cloud_search_config.validate!
    end

  end

end
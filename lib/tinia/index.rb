module Tinia
  module Index

    def self.included(klass)
      klass.send(:include, InstanceMethods)
      klass.send(:extend, ClassMethods)
      klass.class_eval do
        cattr_accessor :in_cloud_search_batch_documents
        self.in_cloud_search_batch_documents = false

        # set up our callbacks
        after_save(:add_to_cloud_search_callback)
        after_destroy(:delete_from_cloud_search_callback)
      end
    end

    module InstanceMethods

      # Default after_save callback.
      # Can be overriden by the model.
      def add_to_cloud_search_callback
        self.add_to_cloud_search
      end

      # Default after_destroy callback.
      # Can be overriden by the model.
      def delete_from_cloud_search_callback
        self.delete_from_cloud_search
      end

      # add ourself as a document to CloudSearch
      def add_to_cloud_search
        self.class.cloud_search_add_document(
          self.cloud_search_document
        )
      end

      # empty implementation - re-implement
      # or we might end up doing some meta-programming here
      def cloud_search_data
        {}
      end

      # wrapper for a fully formed AWSCloudSearch::Document
      def cloud_search_document
        self.class.cloud_search_document.tap do |d|
          d.id = self.id
          self.cloud_search_data.each_pair do |k, v|
            d.add_field(k.to_s, v)
          end
        end
      end

      # add ourself as a document to CloudSearch
      def delete_from_cloud_search
        self.class.cloud_search_delete_document(
          self.cloud_search_document
        )
      end

    end

    module ClassMethods

      # wrapper for a fully formed AWSCloudSearch::Document
      def cloud_search_document
        AWSCloudSearch::Document.new.tap do |d|
          d.lang = "en"
          d.version = Time.now.utc.to_i
          # class name
          d.add_field("type", self.base_class.name)
        end
      end

      # class method to add documents
      def cloud_search_add_document(doc)
        self.cloud_search_batcher_command(:add_document, doc)
      end

     # class method to add documents
      def cloud_search_delete_document(doc)
        self.cloud_search_batcher_command(:delete_document, doc)
      end

      # perform all add/delete operations within a buffered
      # DocumentBatcher
      def cloud_search_batch_documents(&block)
        begin
          self.in_cloud_search_batch_documents = true
          yield
          # final flush for any left over documents
          self.cloud_search_document_batcher.flush
        ensure
          self.in_cloud_search_batch_documents = false
        end
      end

      # reindex the entire collection
      def cloud_search_reindex(*args)
        self.cloud_search_batch_documents do
          self.find_each(*args) do |record|
            Tinia.logger.debug("Adding record #{record.id}")
            record.add_to_cloud_search
          end
        end
      end

      # remove all documents from cloud_search_domain
      def cloud_search_clear_index
        total_entries = self.cloud_search(:per_page => 1).total_entries
        Tinia.logger.debug("Removing #{total_entries} documents...")

        ids = self.cloud_search(:per_page => total_entries).cloud_search_ids

        # delete all documents.
        # the CloudSearch API does not have a "delete all" method, so
        # delete in batches.
        self.cloud_search_batch_documents do
          ids.each do |id|
            Tinia.logger.debug("Removing record #{id}")
            doc = self.cloud_search_document
            doc.id = id
            self.cloud_search_delete_document(doc)
          end
        end if ids.any? # CloudSearch returns an error if the batch is empty
      end

      # rebuild an index from scratch.
      def cloud_search_rebuild(*args)
        self.cloud_search_clear_index
        self.cloud_search_reindex(*args)
      end

      # new instance of AWSCloudSearch::DocumentBatcher
      def cloud_search_document_batcher
        @cloud_search_document_batcher ||= begin
          self.cloud_search_connection.new_batcher
        end
      end

      protected
      # send a command to the batcher and then conditionally flush
      # depending on whether we are in a cloud_search_batch_documents
      # block
      def cloud_search_batcher_command(command, doc)
        # send the command to our batcher
        self.cloud_search_document_batcher.send(command, doc)

        # if we are not in a batch_documents block, flush immediately
        unless self.in_cloud_search_batch_documents
          self.cloud_search_document_batcher.flush
        end
      end
    end

  end
end
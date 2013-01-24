module Tinia

  class QueryBuilder

    def initialize(klass, query, opts)
      @klass = klass
      @query = query
      @opts  = opts
    end

    def build

      AWSCloudSearch::SearchRequest.new.tap do |req|

        bq_terms = ["type:'#{@klass.base_class.name}'"]

        if @query.present?
          if @query =~ /[:\)\(']/
            # The query is already an expression, not just a text phrase
            bq_terms << @query
          else
            bq_terms << "'#{@query}'"
          end
        end

        # Every key in the opts hash, with exception of these four below, is considered
        # a filter key, that is, the key-value pair will be converted to a term in the
        # boolean query (bq) that will be sent to CloudSearch.
        # These four are CloudSearch parameters on their own, and so are treated differently.

        filters = @opts.reject {|k, v| [:page, :per_page, :order_by, :sort_mode].include?(k)}

        filters.each do |field, value|
          bq_terms << case value
            when Array then array_param(field, value)
            when Range then range_param(field, value)
            else simple_param(field, value)
          end
        end

        req.bq    = to_and_query(bq_terms.reverse) # TODO: remove reverse?
        req.size  = @opts[:per_page].to_i
        req.start = (@opts[:page].to_i - 1) * @opts[:per_page].to_i

        if @opts[:order_by].present?
          req.rank = @opts[:order_by].to_s
          req.rank = ('-' + req.rank) if @opts[:sort_mode] == :desc
        end

      end

    end

    def simple_param(key, value)
      index_field = @klass.base_class.cloud_search_config.find_index_field(key)

      if index_field
        index_field.to_param(value)
      else
        raise Tinia::MissingIndexField.new(key)
      end

    end

    def array_param(key, value)
      to_or_query(value.map {|val| simple_param(key, val)})
    end

    def range_param(key, value)
      "#{key}:#{value}"
    end

    def to_and_query(terms)
      "(and #{terms.join(' ')})"
    end

    def to_or_query(terms)
      "(or #{terms.join(' ')})"
    end

  end

end
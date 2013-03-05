module Tinia

  class Configuration

    attr_accessor :index_fields, :cloud_search_domain, :cloud_search_region

    def initialize(klass)
      @index_fields = {}

      config_path = File.join(Rails.root, 'config', 'cloud_search.yml')

      if File.exists? config_path
        config = YAML.load(File.open(config_path) {|f| f.read})
        class_config = config[klass.table_name]

        class_config['index_fields'].each do |field_name, field_options|
          @index_fields[field_name] = IndexField.new(field_options.merge(:name => field_name))
        end

        @cloud_search_domain = class_config['search_domain']
        @cloud_search_region = class_config['region']
      end
    end

    def find_index_field(field)
      @index_fields[field.to_s]
    end

    # ensure config is all set
    def validate!
      unless @cloud_search_domain.present?
        raise Tinia::MissingSearchDomain.new(self)
      end
    end

  end

  class IndexField

    attr_accessor :name, :type, :search_enabled, :facet_enabled, :result_enabled

    def initialize(args)
      args.each do |attribute, value|
        self.send("#{attribute}=", value)
      end
    end

    def to_param(value)
      case @type.to_sym
        when :uint then "#{@name}:#{value.to_i}"
        when :literal, :text then "#{@name}:'#{value}'"
        else raise Tinia::UnknownIndexFieldType.new(@type)
      end
    end

  end

end
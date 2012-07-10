module Tinia
  class MissingSearchDomain < Exception
    # constructor
    def initialize(klass)
      super("You must define a cloud_search_domain for #{klass}")
    end
  end
  
  class MissingIndexField < Exception
    def initialize(field_name)
      super("Could not find configuration details for index field #{field_name}. 
             Check your cloud_search.yml configuration file.")
    end
  end
  
  class UnknownIndexFieldType < Exception
    def initialize(type)
      super("Unknown index field type: #{type}. Expected one of literal, text, uint. 
             Check your cloud_search.yml configuration file.")
    end
  end
end

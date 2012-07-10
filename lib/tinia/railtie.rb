module Tinia
  class Railtie < Rails::Railtie

    initializer "tinia.activate" do
      Tinia.activate_active_record!
    end
    
    initializer "tinia.logger" do
      Tinia.logger = Rails.logger
    end
    
    console do
      Tinia.logger = Logger.new(STDOUT)
    end
    
  end
  
end
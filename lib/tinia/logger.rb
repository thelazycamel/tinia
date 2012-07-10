module Tinia
  
  def Tinia.logger
    @@logger ||= Logger.new(STDOUT)
  end
  
  def Tinia.logger=(logger)
    @@logger = logger
  end
  
end
#Sensor encapsulates a WS7000 sensor record.
class Sensor
  attr_accessor :name, :units, :value, :new_value
  
  def initialize(name, value, units, new_value=true)
    @name, @value, @units, @new_value = name, value, units, new_value
  end
end

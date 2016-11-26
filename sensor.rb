#!/usr/local/bin/ruby
require_relative 'nibble.rb'

class Sensor
  attr_accessor :name, :units, :value, :new_value
  def initialize(datetime, name, value, units, new_value=true)
    @name, @value, @units, @new_value = name, value, units, new_value
  end
end

class Sensors
  RAIN_UNITS=0.5 #mm per reading

  attr_accessor :sensor, :timestamp
  
=begin
  Request Dataset
  <SOH><0x1><Chksum><EOT>
    Response from weather station: (34/60 Bytes) Mine has additional 0 byte, so 35/61 bytes are received.
    1. Data available 
      Block no.: 2 bytes  Number of the block in the memory 
                 (no relation to time. Serves to control dataset registered twice).)
      Time:      2 bytes Age of the dataset in minutes up to the current time.
                 age = ( data[2] & 0xff )  + ( data[3] << 8 & 0xff00 );
      Data:      30 (9 sensors) or 56 (16 sensors) bytes
    2. No data available: <DLE>
=end
  def initialize(data)
    @sensor = [ ]
    if data.length == 2 #In nibbles
      if data.get_byte(0) == 0x10 #DLE
        puts "No Data"
      else
        raise "Short Packet, got #{"%02X" % x}"
      end
    else
      n = 0
      index = data.get_ushort(n) #We can ignore this, as the Time gives us a unique ID
      n += 4
      @timestamp = Time.now - 60 * data.get_ushort(n) 
      n += 4
      (1..8).each do |s|
        humidity, new_value = data.get_ubyte_et_topbit(n+3)
        @sensor <<  Sensor.new("Temp#{s}", data.get_bcd(n,3)/10.0, 'C', new_value)
        @sensor <<  Sensor.new("Humidity#{s}", humidity , '%', new_value)
        n += 5
      end

      rain = data.get_short(n); n+=4
      @sensor <<  Sensor.new("Rainfall", rain&0xfff * RAIN_UNITS, 'mm', rain&0x8000 != 0)

      wind_speed, new_value = data.get_ubcd_et_topbit(n,4); n+=4
      @sensor <<  Sensor.new("Wind speed", wind_speed/ 10.0, 'km', new_value)
      wind_direction_top_nibble = data.get_ubcd(n+2,1)
      @sensor <<  Sensor.new("Wind Direction", data.get_ubcd(n,2) + (wind_direction_top_nibble & 0x3) * 100, 'Degrees', new_value)
      @sensor <<  Sensor.new("Wind Deviation", (wind_direction_top_nibble >> 2) & 0x3 , 'Degrees', new_value)
      n+=3

      humidity, new_value = data.get_ubyte_et_topbit(n+6)
      @sensor <<  Sensor.new("Pressure_I", data.get_ubcd(n,3) + 200 , 'hPa', new_value)
      @sensor <<  Sensor.new("Temp_I", data.get_bcd(n+3,3)/10.0, 'C', new_value)
      @sensor <<  Sensor.new("Humidity_I", humidity , '%', new_value)
      n += 8

      if data.length > 70 #We have 16 Sensors. 
        humidity, new_value = data.get_ubyte_et_topbit(n+3)
        @sensor <<  Sensor.new("Temp9", data.get_bcd(n,3)/10.0, 'C', new_value)
        @sensor <<  Sensor.new("Humidity9", humidity , '%', new_value)
        n += 5

        (10..15).each do |s|
          humidity, new_value = data.get_ubyte_et_topbit(n+6)
          @sensor <<  Sensor.new("Pressure#{s}", data.get_ubcd(n,3) + 200, 'hPa', new_value)
          @sensor <<  Sensor.new("Temp#{s}", data.get_bcd(n,3)/10.0, 'C', new_value)
          @sensor <<  Sensor.new("Humidity#{s}", humidity , '%', new_value)
          n += 8
        end
      end
    end
  end
    
  def to_s
    s = "#{timestamp.strftime("%Y-%m-%dT%H:%M:%S")}\n"
    @sensor.each do |s|
      s += "#{s.name} #{s.value} #{s.units}"
    end
    return s
  end
  
end





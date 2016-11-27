require_relative 'nibble.rb'


class Sensors
  RAIN_UNITS=0.5 #mm per reading

  attr_accessor :sensor, :timestamp


  def initialize(the_data_byte_array)
    data = Nibble.new(the_data_byte_array)
    @sensor = [ ]
    if data.length == 2 #In nibbles
      if data.get_byte(0) != 0x10 #DLE
        raise "Short Packet, got #{"%02X" % data.get_byte(0)}"
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
      @sensor <<  Sensor.new("Rainfall", (rain&0xfff) * RAIN_UNITS, 'mm', (rain&0x8000) != 0)

      wind_speed, new_value = data.get_ubcd_et_topbit(n,4)
      n+=4
      @sensor <<  Sensor.new("Wind speed", wind_speed / 10.0, 'km', new_value)
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

  def data?
	@sensor.length > 0
  end

  def to_data_row
    if @sensor.length > 0
      print "#{timestamp.strftime("%Y-%m-%d %H:%M:%S")}"
      @sensor.each {|s| print s.new_value ? "\t#{s.value}" : "\t-" }
      puts
    end
  end

  def to_s
    if @sensor.length > 0
      str = "#{timestamp.strftime("%Y-%m-%dT%H:%M:%S")}\n"
      @sensor.each do |s|
        str += "#{s.name} #{s.value} #{s.units} #{s.new_value}\n"
      end
      return str
    else
      return "No Data"
    end
  end

end

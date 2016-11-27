#!/usr/local/bin/ruby
require_relative 'lib/ws7000.rb'

#Usage: ws7000.rb command [value]
#Command 0 Poll DCF Time
#Command 1 Request dataset
#Command 2 select next dataset
#Command 3 activate 8 sensors
#Command 4 activate 16 sensors
#Command 5
#Command 6 interval_time Set WS7000 polling interval of sensors (2 to 60 seconds).
#Command 12 #Loop through Commands 1 and 2 until no more data

weather_station = WeatherStation.new
begin
  if ARGV.length == 1
    weather_station.command(ARGV[0].to_i)
  elsif ARGV.length == 2 && ARGV[0].to_i == 6
    weather_station.command(ARGV[0].to_i, ARGV[1].to_i)
  else
    puts "Error: ws7000.rb [0-6] [time interval, if 6]"
  end
rescue Weather_exception => error
  STDERR.puts error
end

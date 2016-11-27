# ws7000
La Crosse ws7000 Weather Station Serial interface classes, and test app

Used as the basis for logging Weather info from my WS7000 into a log file,
and graphing this on the Wikarekare.org web site (Outputs a single line, with
all sensors data). Not much of the Station still works, only temperature,
pressure and humidity sensors.

Usage: ws7000.rb command [value]
  0 Poll DCF Time
  1 Request dataset
  2 select next dataset
  3 activate 8 sensors
  4 activate 16 sensors
  5 Status request
  6 interval_time Set WS7000 polling interval of sensors (2 to 60 seconds).
  12 Psuedo command. Loops through Commands 1 and 2 until no more data

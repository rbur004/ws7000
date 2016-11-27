#!/usr/local/bin/ruby
# encoding: BINARY
#require 'rubygems'
require 'serialport'
#require 'readbytes'
require_relative 'sensor.rb'
require_relative 'dcf77.rb'
require_relative 'weather_exception.rb'

class WeatherStation

  attr_accessor :response

  PORT = '/dev/ttyUSB0'
  #PORT = '/dev/tty.usbserial-FT8X58LF'
  #PORT = '/dev/ttyu0'
  BAUD = 9600
  BITS = 8
  STOPBITS = 2
  PARITY = SerialPort::EVEN

  SOT = 0x01
  STX = 0x02 #in message STX maps to ENQ DC2
  STX_ESC = [0x05,0x12]
  ETX = 0x03 #in message ETX maps to ENQ DC3
  ETX_ESC = [0x05,0x13]
  EOT = 0x04
  ENQ = 0x05
  ENQ_ESC = [0x05,0x15]
  ACK = 0x06
  DLE = 0x10
  DC2 = 0x12
  DC3 = 0x13
  NAK = 0x15

	def initialize(port = PORT)
	  @port = port
    open_serial_port(port)
	end

  def close
    @sp.close if @sp != nil
    @sp = nil
  end

  def command(cmd, arg = 2)
    return if @sp == nil
    #<SOT><CMD_BYTE><CHECK_SUM><EOT>
    case cmd
    when 0 #Poll DCF Time
      exchange("\x01\x30\xcf\x04", 7)
      puts DCF77.new(@response).to_s
    when 1 #Request dataset
      exchange("\x01\x31\xce\x04", 61)
      #@response.each { |r| print "%02X " % r }
      s =  Sensors.new(@response)
      if s.data?
        puts s.to_data_row
        puts Sensors.new(@response).to_s
      end
    when 2 #select next dataset
      exchange("\x01\x32\xcd\x04",1)
      exit @response[0] == ACK ? 0 : 1
    when 3 #activate 8 sensors
      exchange("\x01\x33\xcc\x04",1)
      exit @response[0] == ACK ? 0 : 1
    when 4 #activate 16 sensors
      exchange("\x01\x34\xcb\x04",1)
      exit @response[0] == ACK ? 0 : 1
    when 5
      exchange("\x01\x35\xca\x04", 21)
      @response.each { |r| print "%02X " % r }
      puts
    when 6 #set interval time
      #<SOT><CMD_BYTE><ARGUMENT><CHECK_SUM><EOT>
      raise Weather_exception, "Interval Range 2..60" if arg > 60 || arg < 2
      exchange("\x01\x36#{arg.chr}#{(0xc9-arg).chr}\x04", 1)
      exit @response[0] == ACK ? 0 : 1
    when 12 #Loop through 1 and 2
      begin
        exchange("\x01\x31\xce\x04", 61)
        s = Sensors.new(@response)
        exchange("\x01\x32\xcd\x04",1)
        if s.data?
	  puts s.to_data_row
        else
          break
        end
      end while( @response[0] == ACK )
    end
  end

  def checksum(message)
    i =  message.length + 2
    message.each { |b| i += b}
    (256 - i) & 0xFF
  end

  def exchange(send_bytes, response_nbytes )
    @response = []
    @sp.rts = 0
    @sp.dtr = 0
    @sp.dtr = 1
    begin
      x = @sp.readbyte #should get an ETX after toggling the DTR
      raise Weather_exception, "Bad packet: No ETX" if x != ETX

      @sp.write(send_bytes)
      @sp.flush()
      x = @sp.readbyte #should get an ETX after toggling the DTR
      raise Weather_exception, "Bad packet: No STX" if x != STX

      length = @sp.readbyte
      STDERR.puts "Length = #{length}"

      i = 1
      escaped = false
      begin
        x = @sp.readbyte
        if length > 0
          STDERR.print "#{i}: #{"%02X" % x} "
          i += 1
          if x == ENQ 
            escaped = true
          elsif escaped
            case x
            when DC2; @response << STX
            when DC3; @response << ETX
            when NAK; @response << ENQ
            else @response << x
            end
            escaped = false
            length -= 1
          else
            @response << x
            length -= 1
          end
        elsif length == 0
          @checksum = x
          length = -1
          raise Weather_exception, "Checksum Error #{"%02X"%x}"  if x != checksum(@response)
        elsif x != ETX
          raise Weather_exception, "Missing ETX"
        end
      end while x != ETX
      
      if @response[0] == NAK #Got a NAK packet
        raise Weather_exception, "Comms Error"
      end
    ensure   
      @sp.dtr = 0
      STDERR.puts
    end
  end

  def to_s
    s = ""
    @response.each { |r| s += "#{"%02X" % r} " }
    return s
  end
  
  private
  def open_serial_port(port = PORT, speed = BAUD, bits = BITS, stopbits = STOPBITS, parity = PARITY)
    begin
      @sp = SerialPort.new(port, speed, bits, stopbits, parity)
      @sp.flow_control = SerialPort::NONE
      @sp.binmode
      @sp.read_timeout = 30000
      #puts "DTR #{@sp.dtr} DSR #{@sp.dsr} RTS #{@sp.rts} CTS #{@sp.cts} DCD #{@sp.dcd} RI #{@sp.ri}"
    rescue => error
      STDERR.puts Weather_exception, "open_serial_port: " + error.to_s
      @sp = nil
    end
  end

end

x = WeatherStation.new
begin
  if ARGV.length == 1
    x.command(ARGV[0].to_i)
  elsif ARGV.length == 2
    x.command(ARGV[0].to_i, ARGV[1].to_i)
  else
    puts "Error: ws7000.rb [0-6] [time interval, if 6]"
  end
rescue Weather_exception => error
  STDERR.puts error
end

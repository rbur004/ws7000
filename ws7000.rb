#!/usr/local/bin/ruby
# encoding: BINARY
require 'rubygems'
require 'serialport'
#require 'readbytes'
require_relative 'sensor.rb'
require_relative 'dcf77.rb'
require_relative 'weather_exception.rb'

class WeatherStation

  attr_accessor :response

  #PORT = '/dev/ttyUSB0'
  PORT = '/dev/tty.usbserial-FT8X58LF'
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
      puts Sensors(@response).to_s
    when 2 #select next dataset
      exchange("\x01\x32\xcd\x04",1)
    when 3 #activate 8 sensors
      exchange("\x01\x33\xcc\x04",1)
    when 4 #activate 16 sensors
      exchange("\x01\x34\xcb\x04",1)
    when 5
      exchange("\x01\x35\xca\x04", 21)
      @response.each { |r| puts "%02X " % r }
    when 6 #set interval time
      #<SOT><CMD_BYTE><ARGUMENT><CHECK_SUM><EOT>
      raise Weather_exception, "Interval Range 2..60" if arg > 60 || arg < 2
      exchange("\x01\x36#{arg.chr}#{0xc9-arg}\x04", 1)
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
      #puts "Length = #{length}"

      i = 1
      escaped = false
      begin
        x = @sp.readbyte
        if length > 0
          print "#{i}: #{"%02X" % x} "
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
          raise Weather_exception, "Checksum Error" if x != checksum(@response)
          #puts "Checksum: #{"%02X"%x}"
        elsif x != ETX
          raise Weather_exception, "Missing ETX"
        end
      end while x != ETX
      
      if @response[0] == NAK #Got a NAK packet
        raise Weather_exception, "Comms Error"
      end
    ensure   
      @sp.dtr = 0
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
      puts Weather_exception, "open_serial_port: " + error.to_s
      @sp = nil
    end
  end

end

x = WeatherStation.new
  #x.command(ARGV[0].to_i)
begin
  x.command(5)
rescue Weather_exception => error
  puts error
end

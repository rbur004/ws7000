require 'serialport'
require_relative 'sensors.rb'
require_relative 'dcf77.rb'
require_relative 'weather_exception.rb'

#Handles sending and receiving commands from the WS7000
class WeatherStation

  attr_accessor :response

  PORT = '/dev/ttyUSB0' #My Linux box
  #PORT = '/dev/tty.usbserial-FT8X58LF' #My Mac
  #PORT = '/dev/ttyu0' #FreeBSD box
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

  #WeatherStation.new
  # @param port [String] File system name of serial interface
	def initialize(port = PORT)
	  @port = port
    open_serial_port(port)
	end

  #Close the serial port
  def close
    @sp.close if @sp != nil
    @sp = nil
  end

  #Send a command to the WS7000, and read the response
  # @param cmd [Numeric] Command, from one of the following
  #    Command 0 Poll DCF Time
  #    Command 1 Request dataset
  #    Command 2 select next dataset
  #    Command 3 activate 8 sensors
  #    Command 4 activate 16 sensors
  #    Command 5
  #    Command 6 interval_time Set WS7000 polling interval of sensors (2 to 60 seconds).
  #    Command 12 #Loop through Commands 1 and 2 until no more data
  # @param arg [numeric] Command 6 takes optional poll time in seconds (Defaults to 2)

  def command(cmd, arg = 2)
    return if @sp == nil
    #<SOT><CMD_BYTE><CHECK_SUM><EOT>
    case cmd
=begin
    Request DCF Time
    <SOH><0x30><Chksum><EOT>
=end
    when 0 #Poll DCF Time
      exchange("\x01\x30\xcf\x04", 7)
      puts DCF77.new(@response).to_s
=begin
    Request Dataset
  	<SOH><0x31><Chksum><EOT>
  		Response from weather station: (34/60 Bytes) Mine has additional 0 byte, so 35/61 bytes are received.
  		1. Data available
  			Block no.: 2 bytes  Number of the block in the memory
  			           (no relation to time. Serves to control dataset registered twice).)
  			Time:      2 bytes Age of the dataset in minutes up to the current time.
  								 age = ( data[2] & 0xff )  + ( data[3] << 8 & 0xff00 );
  			Data:      30 (9 sensors) or 56 (16 sensors) bytes
  		2. No data available: <DLE>
=end
      when 1 #Request dataset
      exchange("\x01\x31\xce\x04", 61)
      #@response.each { |r| print "%02X " % r }
      s =  Sensors.new(@response)
      if s.data?
        puts s.to_data_row
        puts Sensors.new(@response).to_s
      end
=begin
  	Select Next Dataset
  		<SOH><0x32><Chksum><EOT>
  			Response from weather station: (1 Byte)
  				1. Next dataset available : <ACK> 0x06
  				2. No dataset available:    <DLE> 0x10
=end
    when 2 #select next dataset
      exchange("\x01\x32\xcd\x04",1)
      exit @response[0] == ACK ? 0 : 1
=begin
  	Set 8 Sensors
  		<SOH><0x33><Chksum><EOT>
  		Response from weather station: (1 Byte)
  		<ACK>
=end
    when 3 #activate 8 sensors
      exchange("\x01\x33\xcc\x04",1)
      exit @response[0] == ACK ? 0 : 1
=begin
    set 16 Sensors
  	<SOH><0x34><Chksum><EOT>
  	Response from weather station: (1 Byte)
  	<ACK>
=end
    when 4 #activate 16 sensors
      exchange("\x01\x34\xcb\x04",1)
      exit @response[0] == ACK ? 0 : 1
=begin
    	Status
    	 <SOH><0x35><Chksum><EOT>
    	Response from weather station: (21 Byte)
    	Bytes 1 - 18
    			S:1-8 Temp/Hum
    			9 Rain,
    			10 Wind
    			11 Indoor Temp/Hum/Pres
    			12 S9:Temp/Hum
    			13-15 S10-15:Temp/Hum/Pres
    		Byte  >= 0x10 if sensor present
    		value >  0x10 number of error
    	Byte 19 Sample Interval in minutes
    	Byte 20
    	  bit 0 DFC77 time receiver active
    		bit 1 HF if set
    		bit 2 8/16 Sensors
    		bit 3 DFC Synchronized (Not likely in NZ)
    	Byte 21 Version Number
=end
      when 5 #Request Status
      exchange("\x01\x35\xca\x04", 21)
      @response.each { |r| print "%02X " % r }
      puts
=begin
    Set Interval time
  	 <SOH><0x36><minutes><Chksum><EOT>
  		minutes range 1..60
  	 Response from weather station: (1 Byte)
  	<ACK> if in range
  	<DLE> if out of range
=end
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

  # @return [Numeric] WS7000 message checksum
  def checksum(message)
    i =  message.length + 2
    message.each { |b| i += b}
    (256 - i) & 0xFF
  end

  #Actual exchange, of command string, and response from WS7000
  #    Sets @response with response line from WS7000
  # @param send_bytes [String] command being sent
  # @param response_nbytes [Numeric] Response buffer should have this many bytes.
  # @raise [Weather_exception] on checksum error, missing ETX, or a NAK
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

      # not available <STX 02h> <01h> <NAK 15h> <0E8h> <ETX 03h>
      if @response[0] == NAK #Got a NAK packet
        raise Weather_exception, "Comms Error"
      end
    ensure
      @sp.dtr = 0
      STDERR.puts
    end
  end

  # @return [String] Response as a Hex String
  def to_s
    s = ""
    @response.each { |r| s += "#{"%02X" % r} " }
    return s
  end

  private
  # Open the serial port.
  #    Sets @sp file descriptor for the connection.
  # @param port [String] File system path and filename of serial device
  # @param speed [Numeric] Serial port Baud rate
  # @param bits [Numeric] Number of bits in a byte. Usually 7 or 8
  # @param stopbits [Numeric] Number of stop bits after a byte
  # @param parity [SerialPort Constant] Even, Odd or None.
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

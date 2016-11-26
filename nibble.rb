class Nibble 
	attr_accessor :array
	
	def initialize(*argv)
		if argv.length == 1 && argv[0].class == String
			@array = argv[0].unpack('C*')
		else
			@array = Array.new(*argv)
		end
	end
	
	def self.[](*argv)
		Nibble.new(argv)
	end
	
	def [](arg1, arg2 = nil)
		if arg2 != nil
			if arg2 > 0
				self[(arg1..arg2)]
			else 
				self[(arg1..(@array.length * 2 + arg2))]
			end
		elsif arg1.class == Range
			r = []
			arg1.each { |i| r << self[i]}
			return r
		else
			(arg1 & 1) == 0 ? @array[(arg1/2).to_i] & 0x0F : (@array[(arg1/2).to_i] >> 4) & 0x0F 
		end
	end
	
	def []=(i,v)
		if (i & 1) == 0
			if @array[(i/2).to_i] != nil
				@array[(i/2).to_i] &= 0xF0 #Clear bottom Nibble
				@array[(i/2).to_i] |= (v & 0xF) #Set bottom Nibble to v
			else
				@array[(i/2).to_i] = v & 0xF
			end
		else
			if @array[(i/2).to_i] != nil
				@array[(i/2).to_i] &= 0x0F #Clear top Nibble
				@array[(i/2).to_i] |= (v << 4) #Set top Nibble to v
			else
				@array[(i/2).to_i] = v << 4
			end
		end
	end
	
	def each
		@array.each do |v|
			yield v & 0x0F #Bottom Nibble
			yield (v >> 4) & 0x0F #Top Nibble
		end
	end
	alias each_nibble each
	
	def get_byte(nibble)
		nibble & 1 ? self[nibble] | (self[nibble+1] << 4) : @array[nibble/2]
	end
	
	def get_ubyte(nibble)
		(nibble & 1 ? self[nibble] | (self[nibble+1] << 4) : @array[nibble/2]) & 0xFF
	end
	
	def get_ubyte_et_topbit(nibble)
		r = (nibble & 1 ? self[nibble] | (self[nibble+1] << 4) : @array[nibble/2]) 
		return r & 0x7F, (r & 0x80) != 0
	end
	
	def each_byte
		@array.each { |a| yield a }
	end
	
	def get_short(nibble)
		low = get_byte(nibble)
		high = get_byte(nibble + 2)
		return ((high & 0x80) != 0) ? -(((high & 0x7F) << 8) + low) : high << 8 + low
	end

	def get_ushort(nibble)
		low = get_byte(nibble)
		high = get_byte(nibble + 2)
		return ((high << 8) + low) & 0xFFFF
	end
	
	def get_ushort_et_topbit(nibble)
		low = get_byte(nibble)
		high = get_byte(nibble + 2)
		return (((high & 0x7F) << 8) + low)  & 0xFFFF, (high & 0x80) != 0
	end

	def get_bcd(nibble, nibbles)
		r = self[nibble + nibbles - 1]
		r = -r & 0x7 if (r & 0x8) != 0
		(nibble + nibbles - 2).downto(nibble) {|n| r = r * 10 + self[n]}
		return r
	end

	def get_ubcd(nibble, nibbles)
		r = self[nibble + nibbles - 1]
		(nibble + nibbles - 2).downto(nibble) {|n| r = r * 10 + self[n]}
		return r
	end

	def get_ubcd_et_topbit(nibble, nibbles)
		r = self[nibble + nibbles - 1]
		top_bit = (r & 0x8) != 0 
		r &= 0x7
		(nibble + nibbles - 2).downto(nibble) {|n| r = r * 10 + self[n]}
		return r, top_bit
	end

	def each_byte_with_index
		@array.each_with_index { |a,i| yield a,i }
	end
	
	def each_with_index
		@array.each_with_index do |v,i|
			yield v & 0x0F, i * 2 #Bottom Nibble
			yield (v >> 4) & 0x0F, i * 2 + 1#Top Nibble
		end
	end
	alias each_nibble_with_index each_with_index
	
	def length
		@array.length * 2 #Always even
	end
			
end

=begin
  puts "Original definition Nibble[0xE1,0xCD]"
  a  = Nibble[0xE1,0xCD]
  puts "Extract with each_with_index"
  a.each { |v| puts "%01X"%v }
  puts "add 2 to nibble 4"
  a[4] = 2
  puts "Extract with each_with_index"
  a.each_with_index { |v,i| puts "#{i}: #{"%01X"%v}" }
  puts "Retrieve with indexing (0..3).each"
  (0..3).each do |i|
    puts "#{i} #{"%01X"%a[i]}"
  end
  puts "Array Range [1..2]"
  a[1..2].each do |v|
    puts "#{"%01X"%v}"
  end

  puts "Array First and last element [0,2]"
  a[0,2].each do |v|
    puts "#{"%01X"%v}"
  end

  puts "Array First and last element [0,-1]"
  a[0,-1].each do |v|
    puts "#{"%01X"%v}"
  end

  puts "Array First and last element [0,-2]"
  a[0,-2].each do |v|
    puts "#{"%01X"%v}"
  end

  puts "Extract bytes, not nibbles"
  a.each_byte do |v|
    puts "#{"%02X"%v}"
  end

  puts "create Nibble from string \"\\xf1\\x2e\\x05\", and output bytes"
  b = Nibble.new("\xf1\x2e\x05")
  b.each_byte do |v|
    puts "#{"%02X"%v}"
  end
  puts "Output again with index"
  b.each_byte_with_index do |v,i|
    puts "#{i} #{"%02X"%v}"
  end
  puts "Output by nibble  with index"
  b.each_nibble_with_index do |v,i|
    puts "#{i} #{"%1X"%v}"
  end
=end



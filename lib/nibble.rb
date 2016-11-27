#WS7000 packets use 4bit nibbles, so to make life simpler
#class Nibble takes a string, read from the WS7000 and
#unpacks it into nibbles, stored in as an array of bytes in @array.
class Nibble
	attr_accessor :array #Nibbles, unpacked from string

	#Nibble.new
	# @param [Array] argv Either a single param, of type String, ar an Array of Nibbles
	# @return [Nibble]
	def initialize(*argv)
		if argv.length == 1 && argv[0].class == String
			@array = argv[0].unpack('C*')
		else
			@array = Array.new(*argv)
		end
	end

	#Nibble[] alternate form of Nibble.new
	# @param [Array] argv Either a single param, of type String, ar an Array of Nibbles
	# @return [Nibble]
	def self.[](*argv)
		Nibble.new(argv)
	end

	#[]
	# @param [Numeric] arg1 is either an index into the Nibble array, or a Range.
	# @param [Numeric] arg2 Optional end of range
	# @return [Array] Single Nibble, or Array of Nibbles, if requesting a Range
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

	#[]=
	# @param [Numeric] Nibble index
	# @param [Numeric] 4 bit value
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

	#Each Iterate through Nibbles.
	# @yield [Numeric]
	def each
		@array.each do |v|
			yield v & 0x0F #Bottom Nibble
			yield (v >> 4) & 0x0F #Top Nibble
		end
	end
	alias each_nibble each

	#  @return [Numeric] Returns two nibbles, as a signed value (Which might not have been byte aligned)
	def get_byte(nibble)
		nibble & 1 ? self[nibble] | (self[nibble+1] << 4) : @array[nibble/2]
	end

	#  @return [Numeric] Returns two nibbles, as an unsigned value (Which might not have been byte aligned)
	def get_ubyte(nibble)
		(nibble & 1 ? self[nibble] | (self[nibble+1] << 4) : @array[nibble/2]) & 0xFF
	end

	#  @return [Numeric, Boolean] Returns two nibbles, as an unsigned value (Which might not have been byte aligned). And true, if top bit is set.
	def get_ubyte_et_topbit(nibble)
		r = (nibble & 1 ? self[nibble] | (self[nibble+1] << 4) : @array[nibble/2])
		return r & 0x7F, (r & 0x80) != 0
	end

	#Each_byte Iterates through pairs of nibbles (i.e through the byte array holding the nibbles).
	# @yield [Numeric]
	def each_byte
		@array.each { |a| yield a }
	end

	#  @return [Numeric] Returns 4 nibbles, as an signed value (Which might not have been byte aligned)
	def get_short(nibble)
		low = get_byte(nibble)
		high = get_byte(nibble + 2)
		return ((high & 0x80) != 0) ? -(((high & 0x7F) << 8) + low) : high << 8 + low
	end

	#  @return [Numeric] Returns 4 nibbles, as an unsigned value (Which might not have been byte aligned)
	def get_ushort(nibble)
		low = get_byte(nibble)
		high = get_byte(nibble + 2)
		return ((high << 8) + low) & 0xFFFF
	end

	#  @return [Numeric, Boolean] Returns 4 nibbles, as an unsigned value (Which might not have been byte aligned). And true, if top bit is set.
	def get_ushort_et_topbit(nibble)
		low = get_byte(nibble)
		high = get_byte(nibble + 2)
		return (((high & 0x7F) << 8) + low)  & 0xFFFF, (high & 0x80) != 0
	end

	#  @return [Numeric] Returns range of nibbles, as an signed Binary Coded Decimal values (Which might not have been byte aligned). And true, if top bit is set.
	def get_bcd(nibble, nibbles)
		r = self[nibble + nibbles - 1]
		r = -r & 0x7 if (r & 0x8) != 0
		(nibble + nibbles - 2).downto(nibble) {|n| r = r * 10 + self[n]}
		return r
	end

	#  @return [Numeric] Returns range of nibbles, as an unsigned Binary Coded Decimal values (Which might not have been byte aligned). And true, if top bit is set.
	def get_ubcd(nibble, nibbles)
		r = self[nibble + nibbles - 1]
		(nibble + nibbles - 2).downto(nibble) {|n| r = r * 10 + self[n]}
		return r
	end

	#  @return [Numeric, Boolean] Returns range of nibbles, as an signed Binary Coded Decimal values, and true is first bit 1 (Which might not have been byte aligned). And true, if top bit is set.
	def get_ubcd_et_topbit(nibble, nibbles)
		r = self[nibble + nibbles - 1]
		top_bit = (r & 0x8) != 0
		r &= 0x7
		(nibble + nibbles - 2).downto(nibble) {|n| r = r * 10 + self[n]}
		return r, top_bit
	end

	#each_byte_with_index Iterates through pairs of nibbles (i.e through the byte array holding the nibbles).
	# @yield [Numeric, Numeric] Bytes value, Array index for Byte
	def each_byte_with_index
		@array.each_with_index { |a,i| yield a,i }
	end

	#each_with_index Iterates through nibbles
	# @yield [Numeric, Numeric] Nibble value, Array index for Nibble
	def each_with_index
		@array.each_with_index do |v,i|
			yield v & 0x0F, i * 2 #Bottom Nibble
			yield (v >> 4) & 0x0F, i * 2 + 1#Top Nibble
		end
	end

	#each_with_index Iterates through nibbles
	# @yield [Numeric, Numeric] Nibble value, Array index for Nibble
	alias each_nibble_with_index each_with_index

	#length
	# @return [Numeric] number of Nibbles, which is always even, as we store bytes.
	def length
		@array.length * 2 #Always even
	end

end

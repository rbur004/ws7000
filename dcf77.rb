#!/usr/local/bin/ruby
require_relative 'nibble.rb'

class DCF77
  attr_reader :time
  def initialize(dcf77)
    if (dcf77.get_ubyte(0) & 0x8) != 0 #We have synchronized with a DCF signal
      @time = Time.local(@dcf77.get_ubcd(12,2) + 100, @dcf77.get_ubcd(10,2), @dcf77.get_ubcd(8,2),
               @dcf77.get_ubcd(2,2), @dcf77.get_ubcd(4,2), @dcf77.get_ubyte(6), 0 )
    else
      @time = Time.now
    end
  end
  
  def to_s
    @time.strftime("%Y-%m-%d %H:%M:%S")
  end
end

#!/usr/local/bin/ruby
require_relative '../lib/nibble.rb'

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

#!/usr/bin/env ruby

#
# Weather update client in Ruby
# Connects SUB socket to tcp://localhost:5556
# Collects weather updates and finds avg temp in zipcode
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'rbzmq'

# Socket to talk to server
puts 'Collecting updates from weather server...'
subscriber = RbZMQ::Socket.new ZMQ::SUB
subscriber.connect 'tcp://localhost:5556'

# Subscribe to zipcode, default is NYC, 10001
filter = ARGV.size > 0 ? ARGV[0] : '10001 '
subscriber.setsockopt(ZMQ::SUBSCRIBE, filter)

# Process 100 updates
COUNT      = 100
total_temp = 0

1.upto(COUNT) do |update_nbr|
  s = subscriber.recv(timeout: -1).to_s

  _zipcode, temperature, _relhumidity = s.split.map(&:to_i)
  print '.'

  total_temp += temperature
end

puts
puts "Average temperature for zipcode '#{filter}' was #{total_temp / COUNT}F"

#!/usr/bin/env ruby

#
# Weather update server in Ruby
# Binds PUB socket to tcp://*:5556
# Publishes random weather updates
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'rbzmq'

publisher = RbZMQ::Socket.new ZMQ::PUB
publisher.bind 'tcp://*:5556'
publisher.bind 'ipc://weather.ipc'

loop do
  # Get values that will fool the boss
  zipcode     = rand(10_000) + 5_000
  temperature = rand(215) - 80
  relhumidity = rand(50) + 10

  update = format('%05d %d %d', zipcode, temperature, relhumidity)
  puts "> #{update}" unless ENV['QUIET']

  publisher.send update
end

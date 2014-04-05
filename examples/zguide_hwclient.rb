#!/usr/bin/env ruby

# Hello World Client

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'rbzmq'

requester = RbZMQ::Socket.new ZMQ::REQ
requester.connect 'tcp://localhost:5555'

10.times do |index|
  puts "Sending Hello #{index}..."

  requester.send "Hello #{index}"
  msg = requester.recv(timeout: 10_000)

  puts "Received: #{msg}"
end

requester.close

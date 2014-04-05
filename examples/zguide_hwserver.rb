#!/usr/bin/env ruby

# Hello World Server

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'rbzmq'

responder = RbZMQ::Socket.new ZMQ::REP
responder.bind 'tcp://*:5555'

loop do
  string = responder.recv(timeout: -1).to_s
  puts "Received: #{string}"

  sleep 1 # Do some work

  responder.send 'World'
end

$LOAD_PATH << File.expand_path("../../../lib", __FILE__)

require "rbzmq"

socket = RbZMQ::Socket.new ZMQ::ROUTER

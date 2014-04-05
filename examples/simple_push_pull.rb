$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'rbzmq'

writer = RbZMQ::Socket.new ZMQ::PUSH
writer.connect 'tcp://127.0.0.1:4237'

writer.send 'My Message!'
writer.send 'My Second Message!'

reader = RbZMQ::Socket.new ZMQ::PULL
reader.bind 'tcp://127.0.0.1:4237'

p reader.recv.to_s
p reader.recv.to_s

writer.close
reader.close

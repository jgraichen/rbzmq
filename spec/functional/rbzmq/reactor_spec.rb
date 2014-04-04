# require 'spec_helper'

# describe RbZMQ::Reactor do
#   let!(:reactor) { RbZMQ::Reactor.new }
#   let!(:receiver) { RbZMQ::Socket.new(ZMQ::PULL).tap { |s| s.bind 'inproc://test' } }
#   let!(:sender) { RbZMQ::Socket.new(ZMQ::PUSH).tap { |s| s.connect 'inproc://test' } }
#   after { receiver.close! }
#   after { sender.close! }
#   after { reactor.close }

#   let(:received_messages) { Queue.new }

#   it 'should select on registered sockets and call callbacks' do
#     reactor.run do
#       monitor = watch(receiver)
#       monitor.on(:read) do
#         puts 'Receive...'
#         received_messages << receiver.recv_string
#       end

#       monitor.interest << :r

#       monitor.interest |= ZMQ::POLLIN
#     end

#     sender.send_string 'MSG1'
#     sender.send_string 'MSG2'

#     sleep 10

#     expect(received_messages).to have(2).items
#     expect(received_messages.pop).to eq 'MSG1'
#     expect(received_messages.pop).to eq 'MSG2'
#   end
# end

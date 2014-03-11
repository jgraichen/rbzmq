require 'spec_helper'

describe RbZMQ::Socket do
  let!(:server) { described_class.new(ZMQ::PULL).tap { |s| s.bind 'inproc://test' } }
  after { server.close! }

  let!(:socket) { described_class.new ZMQ::PUSH }
  after { socket.close! }

  describe 'recv' do
    describe 'timeout' do
      before do
        socket.connect 'inproc://test'
      end

      it 'should poll messages' do
        Thread.new do
          sleep 0.5
          socket.send_string 'TEST'
        end

        start = Time.now
        str   = server.recv_string timeout: 1000

        expect(Time.now - start).to be < 1
        expect(str).to eq 'TEST'
      end

      it 'should raise error when timeout is reached' do
        start = Time.now

        expect{ server.recv_msg timeout: 1000 }.to raise_error Errno::EAGAIN

        expect(Time.now - start).to be_within(0.1).of(1)
      end
    end
  end
end

require 'spec_helper'

describe RbZMQ::Socket do
  let!(:server) do
    described_class.new(ZMQ::PULL).tap{|s| s.bind 'inproc://test' }
  end
  after { server.close! }

  let!(:socket) { described_class.new(ZMQ::PUSH) }
  after { socket.close! }

  describe 'recv' do
    describe 'timeout' do
      before do
        socket.connect 'inproc://test'
      end

      it 'should poll messages' do
        Thread.new do
          sleep 0.2
          socket.send 'TEST'
        end

        start = Time.now
        str   = server.recv(timeout: 1000).to_s

        expect(Time.now - start).to be < 1
        expect(str).to eq 'TEST'
      end

      it 'should raise error when timeout is reached' do
        start = Time.now

        expect{ server.recv(timeout: 1000).to_s }.to raise_error Errno::EAGAIN

        expect(Time.now - start).to be_within(0.1).of(1)
      end
    end

    describe 'multiple' do
      before do
        socket.connect 'inproc://test'
      end

      it 'should receive multiple parts' do
        socket.send %w(TEST MORE)

        msg = server.recv(timeout: 100)
        expect(msg).to be_multipart
        expect(msg.data).to eq 'TEST'
        msg = server.recv(timeout: 100)
        expect(msg.data).to eq 'MORE'
      end
    end
  end
end

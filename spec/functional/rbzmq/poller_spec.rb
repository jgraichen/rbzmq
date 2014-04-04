require 'spec_helper'

describe RbZMQ::Poller do
  let!(:poller) { RbZMQ::Poller.new }
  let!(:receiver) do
    RbZMQ::Socket.new(ZMQ::PULL).tap{|s| s.bind 'inproc://test' }
  end
  let!(:sender) do
    RbZMQ::Socket.new(ZMQ::PUSH).tap{|s| s.connect 'inproc://test' }
  end
  let(:delta) { 0.01 }
  after { receiver.close! }
  after { sender.close! }

  describe '#register' do
    let(:action) { -> { poller.register(receiver, ZMQ::POLLIN) } }
    subject { action }

    it { should change(poller, :size).from(0).to(1) }
  end

  describe '#deregister' do
    let(:action) { -> { poller.deregister(receiver, ZMQ::POLLIN) } }
    subject { action }

    context 'with all events removed' do
      before { poller.register(receiver, ZMQ::POLLIN) }
      it { should change(poller, :size).from(1).to(0) }
    end

    context 'with events leaving' do
      before { poller.register(receiver, ZMQ::POLLIN | ZMQ::POLLOUT) }
      it { should_not change(poller, :size) }
      it { expect(subject.call).to eq ZMQ::POLLOUT }
    end
  end

  describe '#poll' do
    let!(:start_time) { Time.now.to_f }
    let(:end_time) { Time.now.to_f }

    context 'without any registered' do
      it 'should not block' do
        poller.poll(1_000)
        expect(end_time).to be_within(delta).of(start_time)
      end
    end

    context 'with registered ZMQ socket' do
      before { poller.register(receiver, ZMQ::POLLIN) }

      it 'should timeout without event' do
        poller.poll(100)
        expect(end_time).to be > (start_time + 0.1)
      end

      it 'should interrupt on event' do
        Thread.new do
          sleep 0.1
          sender.send_string 'MSG'
        end
        poller.poll(1_000)
        expect(receiver.recv_string).to eq 'MSG'
        expect(end_time).to be < (start_time + 1.0)
      end
    end

    context 'with registered IO' do
      let(:pipe)   { IO.pipe }
      let(:reader) { pipe[0] }
      let(:writer) { pipe[1] }
      before { poller.register(reader, ZMQ::POLLIN) }

      it 'should timeout without event' do
        ret = poller.poll(100)
        expect(ret).to be_a Enumerator
        expect(ret).to have(0).items
        expect(end_time).to be > (start_time + 0.1)
      end

      it 'should interrupt on event' do
        Thread.new do
          sleep 0.1
          writer.write 'MSG'
          writer.close
        end
        ret = poller.poll(1_000)
        expect(end_time).to be < (start_time + 1.0)
        expect(ret).to be_a Enumerator
        expect(ret).to have(1).item
        expect(reader.read_nonblock(4096)).to eq 'MSG'
      end
    end
  end
end

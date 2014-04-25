require 'spec_helper'

describe RbZMQ::Socket do
  let(:socket) { @socket = RbZMQ::Socket.new ZMQ::ROUTER }
  around {|ex| ex.call && @socket && @socket.close }

  describe '#initialize' do
    let(:opts) { Hash.new }
    let(:socket) { @socket = RbZMQ::Socket.new ZMQ::ROUTER, opts }

    context 'opts: ctx' do
      let(:opts) { {ctx: ctx} }

      context 'with valid ctx' do
        subject { socket }

        context 'with ZMQ::Context' do
          let(:ctx) { ZMQ::Context.new }
          it { expect(socket.zmq_ctx).to eq ctx.pointer }
        end

        context 'with RbZMQ::Context' do
          let(:ctx) { RbZMQ::Context.new }
          it { expect(socket.zmq_ctx).to eq ctx.pointer }
        end
      end

      context 'with invalid object' do
        subject { ->{ socket } }

        context 'with String' do
          let(:ctx) { '' }
          it { should raise_error ArgumentError }
        end
      end
    end

    context 'with ZMQ raising an error' do
      let(:zmq_err) { ZMQ::ZeroMQError.new('zmq_source', 42, 21, 'abc MSG') }
      before do
        expect(ZMQ::Socket).to receive(:new).and_raise zmq_err
      end

      subject do
        begin
          socket
        rescue => err
          err
        end
      end

      it { should be_a RbZMQ::ZMQError }
      its(:rc) { should eq 42 }
      its(:result_code) { should eq 42 }
      its(:errno) { should eq 21 }
      its(:error_code) { should eq 21 }
      its(:message) { should eq 'abc MSG' }
      its(:to_s) { should eq '[ERRNO 21, RC 42] abc MSG' }
    end
  end

  describe '#close' do
    subject { socket.close }

    it 'should successfully call #close on ZMQ socket' do
      expect(socket.zmq_socket).to receive(:close).and_return(0)
      expect(subject).to eq true
    end

    it 'should return false on failure' do
      expect(socket.zmq_socket).to receive(:close).and_return(-1)
      should eq false
    end
  end

  describe '#close!' do
    subject { socket.close! }

    it 'should successfully call #close on ZMQ socket' do
      expect(socket.zmq_socket).to receive(:close)
      expect(subject).to eq true
    end

    it 'should raise error on failure' do
      expect(socket.zmq_socket).to receive(:close).and_return(-1)
      expect { subject }.to raise_error RbZMQ::ZMQError
    end
  end

  describe '#bind' do
    subject { socket.bind 'tcp://127.0.0.1:5555' }

    it 'should successfully call #bind on ZMQ socket' do
      expect(socket.zmq_socket).to receive(:bind)
                                   .with('tcp://127.0.0.1:5555').and_return(0)
      expect(subject).to eq socket
    end

    it 'should raise error on failure' do
      expect(socket.zmq_socket).to receive(:bind).and_return(-1)
      expect { subject }.to raise_error RbZMQ::ZMQError
    end
  end

  describe '#connect' do
    subject { socket.connect 'tcp://127.0.0.1:5555' }

    it 'should successfully call #connect on ZMQ socket' do
      expect(socket.zmq_socket).to receive(:connect)
                                   .with('tcp://127.0.0.1:5555').and_return(0)
      expect(subject).to eq socket
    end

    it 'should raise error on failure' do
      expect(socket.zmq_socket).to receive(:connect).and_return(-1)
      expect { subject }.to raise_error RbZMQ::ZMQError
    end
  end

  describe '#send' do
    context 'with single message' do
      let(:dup) { double('ZMQMSG') }
      let(:msg) { RbZMQ::Message.new }
      let(:args) { [msg, 42] }
      subject { socket.send(*args) }
      before { allow(msg).to receive(:to_zmq).and_return(dup) }

      it 'should successfully call #sendmsg on ZMQ socket' do
        expect(socket.zmq_socket).to receive(:sendmsg)
                                     .with(dup, 42).and_return(0)
        expect(subject).to eq socket
      end

      it 'should raise error on failure' do
        expect(socket.zmq_socket).to receive(:sendmsg).and_return(-1)
        expect { subject }.to raise_error RbZMQ::ZMQError
      end

      context 'with :block option' do
        let(:args) { [msg, {block: false}] }

        it 'should set ZMQ::DONTWAIT flag' do
          expect(socket.zmq_socket).to receive(:sendmsg)
                                       .with(dup, ZMQ::DONTWAIT).and_return(0)
          expect(subject).to eq socket
        end
      end

      context 'with :more option' do
        let(:args) { [msg, {more: true}] }

        it 'should set ZMQ::SNDMORE flag' do
          expect(socket.zmq_socket).to receive(:sendmsg)
                                       .with(dup, ZMQ::SNDMORE).and_return(0)
          expect(subject).to eq socket
        end
      end
    end

    context 'with multiple messages' do
      let(:dup1) { double('msg1') }
      let(:dup2) { double('msg2') }
      let(:msg1) { RbZMQ::Message.new }
      let(:msg2) { RbZMQ::Message.new }
      let(:args) { [[msg1, msg2]] }
      subject { socket.send(*args) }
      before { allow(msg1).to receive(:to_zmq).and_return(dup1) }
      before { allow(msg2).to receive(:to_zmq).and_return(dup2) }

      it 'should successfully call #sendmsg on ZMQ socket' do
        expect(socket.zmq_socket).to receive(:sendmsg)
          .with(dup1, ZMQ::SNDMORE).ordered.and_return(0)
        expect(socket.zmq_socket).to receive(:sendmsg)
          .with(dup2, 0).ordered.and_return(0)
        expect(subject).to eq socket
      end

      it 'should raise error on failure' do
        expect(socket.zmq_socket).to receive(:sendmsg)
          .with(dup1, ZMQ::SNDMORE).ordered.and_return(-1)
        expect { subject }.to raise_error RbZMQ::ZMQError
      end

      context 'with :block option' do
        let(:args) { super() + [{block: false}] }

        it 'should successfully call #sendmsg on ZMQ socket' do
          expect(socket.zmq_socket).to receive(:sendmsg)
            .with(dup1, ZMQ::SNDMORE | ZMQ::DONTWAIT).ordered.and_return(0)
          expect(socket.zmq_socket).to receive(:sendmsg)
            .with(dup2, ZMQ::DONTWAIT).ordered.and_return(0)
          expect(subject).to eq socket
        end
      end

      context 'with :more option' do
        let(:args) { super() + [{more: true}] }

        it 'should successfully call #sendmsg on ZMQ socket' do
          expect(socket.zmq_socket).to receive(:sendmsg)
            .with(dup1, ZMQ::SNDMORE).ordered.and_return(0)
          expect(socket.zmq_socket).to receive(:sendmsg)
            .with(dup2, ZMQ::SNDMORE).ordered.and_return(0)
          expect(subject).to eq socket
        end
      end
    end

    context 'with single string' do
      subject { socket.send 'abc', 42 }

      it 'should successfully call #send_string on ZMQ socket' do
        expect(socket.zmq_socket).to receive(:sendmsg)
          .with(kind_of(ZMQ::Message), 42).and_return(0)
        expect(subject).to eq socket
      end

      it 'should raise error on failure' do
        expect(socket.zmq_socket).to receive(:sendmsg).and_return(-1)
        expect { subject }.to raise_error RbZMQ::ZMQError
      end
    end

    context 'with multiple strings' do
      subject { socket.send %w(abc cde), 0 }

      it 'should successfully call #send_strings on ZMQ socket' do
        expect(socket.zmq_socket).to receive(:sendmsg).ordered
          .with(kind_of(ZMQ::Message), ZMQ::SNDMORE).and_return(0)
        expect(socket.zmq_socket).to receive(:sendmsg).ordered
          .with(kind_of(ZMQ::Message), 0).and_return(0)
        expect(subject).to eq socket
      end

      it 'should raise error on failure' do
        expect(socket.zmq_socket).to receive(:sendmsg).and_return(-1)
        expect { subject }.to raise_error RbZMQ::ZMQError
      end
    end
  end

  describe '#setsockopt' do
    subject { socket.setsockopt(ZMQ::SUBSCRIBE, 'ABC') }

    it 'should call #setsockopt on ZMQ socket' do
      expect(socket.zmq_socket).to receive(:setsockopt)
                                   .with(ZMQ::SUBSCRIBE, 'ABC').and_return(0)
      expect(subject).to eq true
    end

    it 'should return false on failure' do
      expect(socket.zmq_socket).to receive(:setsockopt).and_return(-1)
      expect(subject).to eq false
    end
  end
end

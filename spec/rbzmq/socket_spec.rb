require 'spec_helper'

describe RbZMQ::Socket do
  let(:socket) { RbZMQ::Socket.new ZMQ::ROUTER }

  describe '#initialize' do
    let(:opts) { Hash.new }
    let(:socket) { RbZMQ::Socket.new ZMQ::ROUTER, opts }

    context 'opts: ctx' do
      let(:opts) { {ctx: ctx} }

      context 'with valid ctx' do
        subject { socket }

        context 'with ZMQ::Context' do
          let(:ctx) { ZMQ::Context.new }
          its(:zmq_ctx) { should eq ctx.pointer }
        end

        context 'with RbZMQ::Context' do
          let(:ctx) { RbZMQ::Context.new }
          its(:zmq_ctx) { should eq ctx.pointer }
        end
      end

      context 'with invalid object' do
        subject { lambda { socket } }

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
      expect(subject).to eq true
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
      expect(subject).to eq true
    end

    it 'should raise error on failure' do
      expect(socket.zmq_socket).to receive(:connect).and_return(-1)
      expect { subject }.to raise_error RbZMQ::ZMQError
    end
  end

  describe '#send_msg' do
    let(:msg)  { double 'msg' }
    let(:args) { [msg, 42] }
    subject { socket.send_msg *args }

    it 'should successfully call #sendmsg on ZMQ socket' do
      expect(socket.zmq_socket).to receive(:sendmsg)
                                   .with(msg, 42).and_return(0)
      expect(subject).to eq true
    end

    it 'should raise error on failure' do
      expect(socket.zmq_socket).to receive(:sendmsg).and_return(-1)
      expect { subject }.to raise_error RbZMQ::ZMQError
    end

    context 'with :block option' do
      let(:args) { [msg, {:block => false}]}

      it 'should set ZMQ::DONTWAIT flag' do
        expect(socket.zmq_socket).to receive(:sendmsg)
                                     .with(msg, ZMQ::DONTWAIT).and_return(0)
        expect(subject).to eq true
      end
    end

    context 'with :more option' do
      let(:args) { [msg, {:more => true}]}

      it 'should set ZMQ::SNDMORE flag' do
        expect(socket.zmq_socket).to receive(:sendmsg)
                                     .with(msg, ZMQ::SNDMORE).and_return(0)
        expect(subject).to eq true
      end
    end

    context 'with :close option' do
      let(:args) { [msg, {:close => true}]}

      it 'should close message after send' do
        expect(socket.zmq_socket).to receive(:sendmsg)
                                     .with(msg, 0).and_return(0)
        expect(msg).to receive(:close)
        expect(subject).to eq true
      end

      context 'on error' do
        before do
          expect(socket.zmq_socket).to receive(:sendmsg).with(msg, 0).and_return(0)
        end

        it 'should close message after send' do
          expect(msg).to receive(:close)
          expect(subject).to eq true
        end
      end
    end
  end

  describe '#send_msgs' do
    let(:msg1) { double('msg1') }
    let(:msg2) { double('msg2') }
    let(:args) { [[msg1, msg2]] }
    subject { socket.send_msgs *args }

    it 'should successfully call #sendmsg on ZMQ socket' do
      expect(socket.zmq_socket).to receive(:sendmsg).with(msg1, ZMQ::SNDMORE).ordered.and_return(0)
      expect(socket.zmq_socket).to receive(:sendmsg).with(msg2, 0).ordered.and_return(0)
      expect(subject).to eq true
    end

    it 'should raise error on failure' do
      expect(socket.zmq_socket).to receive(:sendmsg).with(msg1, ZMQ::SNDMORE).ordered.and_return(-1)
      expect { subject }.to raise_error RbZMQ::ZMQError
    end

    context 'with :block option' do
      let(:args) { super() + [{:block => false}] }

      it 'should successfully call #sendmsg on ZMQ socket' do
        expect(socket.zmq_socket).to receive(:sendmsg).with(msg1, ZMQ::SNDMORE | ZMQ::DONTWAIT).ordered.and_return(0)
        expect(socket.zmq_socket).to receive(:sendmsg).with(msg2, ZMQ::DONTWAIT).ordered.and_return(0)
        expect(subject).to eq true
      end
    end

    context 'with :more option' do
      let(:args) { super() + [{:more => true}] }

      it 'should successfully call #sendmsg on ZMQ socket' do
        expect(socket.zmq_socket).to receive(:sendmsg).with(msg1, ZMQ::SNDMORE).ordered.and_return(0)
        expect(socket.zmq_socket).to receive(:sendmsg).with(msg2, ZMQ::SNDMORE).ordered.and_return(0)
        expect(subject).to eq true
      end
    end
  end

  describe '#send_string' do
    subject { socket.send_string 'abc', 42 }

    it 'should successfully call #send_string on ZMQ socket' do
      expect(socket.zmq_socket).to receive(:sendmsg)
                                   .with(kind_of(ZMQ::Message), 42)
                                   .and_return(0)
      expect(subject).to eq true
    end

    it 'should raise error on failure' do
      expect(socket.zmq_socket).to receive(:sendmsg).and_return(-1)
      expect { subject }.to raise_error RbZMQ::ZMQError
    end
  end

  describe '#send_strings' do
    subject { socket.send_strings %w(abc cde), 0 }

    it 'should successfully call #send_strings on ZMQ socket' do
      expect(socket.zmq_socket).to receive(:sendmsg).ordered.with(kind_of(ZMQ::Message), ZMQ::SNDMORE).and_return(0)
      expect(socket.zmq_socket).to receive(:sendmsg).ordered.with(kind_of(ZMQ::Message), 0).and_return(0)
      expect(subject).to eq true
    end

    it 'should raise error on failure' do
      expect(socket.zmq_socket).to receive(:sendmsg).and_return(-1)
      expect { subject }.to raise_error RbZMQ::ZMQError
    end
  end

  describe '#recv_msg' do
    subject { socket.recv_msg }

    it 'should call #recvmsg on ZMQ socket' do
      expect(socket.zmq_socket).to receive(:recvmsg).ordered.with(kind_of(ZMQ::Message), 0).and_return(0)
      expect(subject).to be_a ZMQ::Message
    end

    it 'should raise error on failure' do
      expect(socket.zmq_socket).to receive(:recvmsg).and_return(-1)
      expect { subject }.to raise_error RbZMQ::ZMQError
    end
  end

  describe '#recv_string' do
    subject { socket.recv_string }

    it 'should call #recvmsg on ZMQ socket' do
      expect(socket.zmq_socket).to receive(:recvmsg){|msg, flags| msg.copy_in_string 'msg string'}.and_return(0)
      expect(subject).to eq 'msg string'
    end

    it 'should raise error on failure' do
      expect(socket.zmq_socket).to receive(:recvmsg).and_return(-1)
      expect { subject }.to raise_error RbZMQ::ZMQError
    end
  end
end

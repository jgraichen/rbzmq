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

  describe '#sendmsg' do
    let(:msg) { double 'msg' }
    subject { socket.sendmsg msg, 42 }

    it 'should successfully call #sendmsg on ZMQ socket' do
      expect(socket.zmq_socket).to receive(:sendmsg)
                                   .with(msg, 42).and_return(0)
      expect(subject).to eq true
    end

    it 'should raise error on failure' do
      expect(socket.zmq_socket).to receive(:sendmsg).and_return(-1)
      expect { subject }.to raise_error RbZMQ::ZMQError
    end
  end

  describe '#send_string' do
    subject { socket.send_string 'abc', 42 }

    it 'should successfully call #send_string on ZMQ socket' do
      expect(socket.zmq_socket).to receive(:send_string)
                                   .with('abc', 42).and_return(0)
      expect(subject).to eq true
    end

    it 'should raise error on failure' do
      expect(socket.zmq_socket).to receive(:send_string).and_return(-1)
      expect { subject }.to raise_error RbZMQ::ZMQError
    end
  end

  describe '#send_strings' do
    subject { socket.send_strings %w(abc cde), 42 }

    context 'with multiple arguments' do
      subject { socket.send_strings 'abc', 'cde', 42 }

      it 'should successfully call #send_strings on ZMQ socket' do
        expect(socket.zmq_socket).to receive(:send_strings)
                                     .with(%w(abc cde), 42).and_return(0)
        expect(subject).to eq true
      end
    end

    it 'should successfully call #send_strings on ZMQ socket' do
      expect(socket.zmq_socket).to receive(:send_strings)
                                   .with(%w(abc cde), 42).and_return(0)
      expect(subject).to eq true
    end

    it 'should raise error on failure' do
      expect(socket.zmq_socket).to receive(:send_strings).and_return(-1)
      expect { subject }.to raise_error RbZMQ::ZMQError
    end
  end

  describe '#sendmsgs' do
    let(:msg1) { double('msg1') }
    let(:msg2) { double('msg2') }
    subject { socket.sendmsgs [msg1, msg2], 42 }

    context 'with multiple arguments' do
      subject { socket.sendmsgs msg1, msg2, 42 }

      it 'should successfully call #sendmsgs on ZMQ socket' do
        expect(socket.zmq_socket).to receive(:sendmsgs)
                                     .with([msg1, msg2], 42).and_return(0)
        expect(subject).to eq true
      end
    end

    it 'should successfully call #sendmsgs on ZMQ socket' do
      expect(socket.zmq_socket).to receive(:sendmsgs)
                                   .with([msg1, msg2], 42).and_return(0)
      expect(subject).to eq true
    end

    it 'should raise error on failure' do
      expect(socket.zmq_socket).to receive(:sendmsgs).and_return(-1)
      expect { subject }.to raise_error RbZMQ::ZMQError
    end
  end
end

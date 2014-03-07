module RbZMQ

  class Socket

    # @!visibility private
    #
    # Internal {ZMQ::Context} reference.
    #
    attr_reader :zmq_ctx

    # @!visibility private
    #
    # Internal {ZMQ::Socket} reference.
    #
    attr_reader :zmq_socket

    # Allocates a socket of given type for sending and receiving data.
    #
    # @params type [Integer] ZMQ socket type, on if ZMQ::REQ, ZMQ::REP,
    #   ZMQ::PUB, ZMQ::SUB, ZMQ::PAIR, ZMQ::PULL, ZMQ::PUSH, ZMQ::XREQ,
    #   ZMQ::REP, ZMQ::DEALER or ZMQ::ROUTER.
    #
    # @params opts [Hash] Option hash. {:ctx} will be removed, all other
    #   options will be passed to {ZMQ::Socket.new}
    #
    # @option opts [Class] :receiver_class By default {ZMQ::ManagedMessage}
    #   is used for automatic memory management. For manual memory management
    #   override with {ZMQ::Message}.
    #
    # @option opts [Context] :ctx ZMQ context used to initialize socket.
    #   By default {Context.global} is used. Must be {RbZMQ::Context},
    #   {ZMQ::Context} or an {FFI::Pointer}.
    #
    # @raise [ZMQError] On error.
    #
    # @return [Socket] Created socket object.
    #
    def initialize(type, opts = {})
      opts = opts.reverse_merge receiver_class: ZMQ::ManagedMessage

      ctx = opts.fetch(:ctx) { RbZMQ::Context.global }
      ctx = ctx.pointer if ctx.respond_to? :pointer

      unless FFI::Pointer === ctx
        raise ArgumentError.new <<-ERR.strip_heredoc.gsub("\n", '')
            Context must be ZMQ::Context or RbZMQ::Context (respond to
            #pointer) or must be a FFI::Pointer, but #{ctx.class.name} given.
          ERR
      end

      @zmq_ctx    = ctx
      @zmq_socket = ZMQ::Socket.new ctx, type
    rescue ZMQ::ZeroMQError => err
      raise ZMQError.new err
    end

    # Bind this socket to given address.
    #
    # @example
    #   socket = RbZMQ::Socket.new ZMQ::PUB
    #   socket.bind "tcp://127.0.0.1:5555"
    #
    # @params address [String] Address to bind. Must be a supported protocol.
    #
    # @raise [ZMQError] On error.
    #
    def bind(address)
      ZMQError.error! zmq_socket.bind address
    end

    # Connect to given address.
    #
    # @example Bind to single remote address
    #   socket = RbZMQ::Socket.new ZMQ::PUSH
    #   socket.connect "tcp://127.0.0.1:5555"
    #
    # @example Bind to multiple endpoints
    #   socket = RbZMQ::Socket.new ZMQ::ROUTER
    #   socket.connect "tcp://127.0.0.1:5555"
    #   socket.connect "tcp://127.0.0.1:6666"
    #
    # @raise [ZMQError] On error.
    #
    def connect(address)
      ZMQError.error! zmq_socket.connect address
    end

    # Closes the socket. Any unprocessed messages in queue are sent or dropped
    # depending upon the value of the socket option ZMQ::LINGER.
    #
    # @example
    #   socket = RbZMQ::Socket.new ZMQ::PULL
    #   socket.close
    #
    # @return [Boolean] Return true upon success *or* when the socket has
    #   already been closed, false otherwise. Use {close!} to raise an error
    #   on failure.
    #
    def close
      ZMQError.ok? zmq_socket.close
    end

    # Closes the socket. Any unprocessed messages in queue are sent or dropped
    # depending upon the value of the socket option ZMQ::LINGER.
    #
    # @example
    #   socket = RbZMQ::Socket.new ZMQ::PULL
    #   socket.close!
    #
    # @raise [ZMQError] Error raised on error.
    #
    def close!
      ZMQError.error! zmq_socket.close
    end
  end
end

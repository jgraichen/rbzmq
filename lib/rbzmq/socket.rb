module RbZMQ
  #
  # = RbZMQ::Socket
  #
  class Socket
    #
    # Default timeout.
    #
    DEFAULT_TIMEOUT = 5_000

    # @!visibility private
    #
    # Internal ZMQ::Context reference.
    #
    attr_reader :zmq_ctx

    # @!visibility private
    #
    # Internal ZMQ::Socket reference.
    #
    attr_reader :zmq_socket

    # Allocates a socket of given type for sending and receiving data.
    #
    # @param type [Integer] ZMQ socket type, on if ZMQ::REQ, ZMQ::REP,
    #   ZMQ::PUB, ZMQ::SUB, ZMQ::PAIR, ZMQ::PULL, ZMQ::PUSH,
    #   ZMQ::XREQ, ZMQ::REP, ZMQ::DEALER or ZMQ::ROUTER.
    #
    # @param opts [Hash] Option hash. :ctx will be removed, all other
    #   options will be passed to ZMQ::Socket.new.
    #
    # @option opts [Context] :ctx ZMQ context used to initialize socket.
    #   By default {Context.global} is used. Must be {RbZMQ::Context},
    #   ZMQ::Context or an FFI::Pointer.
    #
    # @raise [ZMQError] On error.
    #
    # @return [Socket] Created socket object.
    #
    def initialize(type, opts = {})
      ctx = opts.fetch(:ctx) { RbZMQ::Context.global }
      ctx = ctx.pointer if ctx.respond_to? :pointer

      unless ctx.is_a?(FFI::Pointer)
        raise ArgumentError.new "Context must be ZMQ::Context or " \
          "RbZMQ::Context (respond to #pointer) or must be a FFI::Pointer, "\
          "but #{ctx.inspect} given."
      end

      @zmq_ctx       = ctx
      @zmq_socket    = ZMQ::Socket.new ctx, type
    rescue ZMQ::ZeroMQError => err
      raise ZMQError.new err
    end

    # Return ZMQ socket pointer. Required interface for ZMQ::Poller.
    #
    def socket
      @zmq_socket.socket
    end

    # Bind this socket to given address.
    #
    # @example
    #   socket = RbZMQ::Socket.new ZMQ::PUB
    #   socket.bind "tcp://127.0.0.1:5555"
    #
    # @param address [String] Address to bind. Must be a supported protocol.
    #
    # @raise [ZMQError] On error.
    #
    # @return [RbZMQ::Socket] Self.
    #
    def bind(address)
      ZMQError.error! zmq_socket.bind address
      self
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
    # @return [RbZMQ::Socket] Self.
    #
    def connect(address)
      ZMQError.error! zmq_socket.connect address
      self
    end

    # Closes the socket. Any unprocessed messages in queue are sent or dropped
    # depending upon the value of the socket option ZMQ::LINGER.
    #
    # @example
    #   socket = RbZMQ::Socket.new ZMQ::PULL
    #   socket.close
    #
    # @return [Boolean] Return true upon success *or* when the socket has
    #   already been closed, false otherwise. Use {#close!} to raise an error
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
    # @raise [ZMQError] Error raised on failure.
    #
    # @return [Boolean] True.
    #
    def close!
      ZMQError.error! zmq_socket.close
      true
    end

    # Set a ZMQ socket object.
    #
    # @return [Boolean] True if success, false otherwise.
    #
    # @see zmq_setsockopt
    #
    def setsockopt(opt, val)
      ZMQError.ok? zmq_socket.setsockopt(opt, val)
    end

    # Queues one or more messages for transmission.
    #
    # @example Send single message or string
    #   begin
    #     message = RbZMQ::Message.new
    #     socket.send message
    #   rescue RbZMQ::ZMQError => err
    #     puts 'Send failed.'
    #   end
    #
    # @example Send multiple messages
    #    socket.send ["A", "B", "C 2"]
    #
    # @param messages [RbZMQ::Message, String, #each] A {RbZMQ::Message} or
    #   string message to send, or a list of messages responding to `#each`.
    #
    # @param flags [Integer] May contains of the following flags:
    #   * 0 (default) - blocking operation
    #   * ZMQ::DONTWAIT - non-blocking operation
    #   * ZMQ::SNDMORE - this message or all messages
    #     are part of a multi-part message
    #
    # @param opts [Hash] Options.
    #
    # @option opts [Boolean] :block If method call should block. Will set
    #   ZMQ::DONTWAIT flag if false. Defaults to true.
    #
    # @option opts [Boolean] :more If this message or all messages
    #   are part of a multi-part message
    #
    # @raise [ZMQError] Raises an error under two conditions:
    #   1. The message(s) could not be enqueued
    #   2. When flags is set with ZMQ::DONTWAIT and the socket
    #      returned EAGAIN.
    #
    # @return [RbZMQ::Socket] Self.
    #
    def send(messages, flags = 0, opts = {})
      opts, flags = flags, 0 if flags.is_a?(Hash)
      flags       = convert_flags(opts, flags)

      if messages.respond_to?(:each)
        send_multiple(messages, flags)
      else
        send_single(messages, flags)
      end

      self
    end

    # Dequeues a message from the underlying queue.
    #
    # By default, this is a blocking operation.
    #
    # @example
    #   message = socket.recv
    #
    # @param flags [Integer] Can be ZMQ::DONTWAIT.
    #
    # @param opts [Hash] Options.
    #
    # @option opts [Boolean] :block If false operation will be non-blocking.
    #   Defaults to true.
    #
    # @option opts [Integer] :timeout Raise a EAGAIN error if nothing was
    #   received within given amount of milliseconds. Defaults
    #   to {DEFAULT_TIMEOUT}. The values `:blocking`, `:infinity`
    #   or `-1` will wait forever.
    #
    # @raise [ZMQError] Raise error under two conditions.
    #   1. The message could not be dequeued
    #   2. When mode is non-blocking and the socket returned EAGAIN.
    #
    # @raise [Errno::EAGAIN] When timeout was reached without receiving
    #   a message.
    #
    # @return [RbZMQ::Message] Received message.
    #
    def recv(flags = 0, opts = {})
      opts, flags = flags, 0 if flags.is_a?(Hash)

      with_recv_timeout(opts) do
        messages = []

        loop do
          rc = zmq_socket.recvmsg((message = ZMQ::Message.new),
                                  convert_flags(opts, flags, [:block]))
          ZMQError.error! rc
          messages << message
          break unless zmq_socket.more_parts?
        end

        RbZMQ::Message.from_zmq(messages)
      end
    end

    private

    def send_multiple(messages, flags)
      flgs = flags | ZMQ::SNDMORE
      last = messages.to_enum(:each).reduce(nil) do |memo, msg|
        send_single(memo, flgs) if memo
        RbZMQ::Message.new(msg)
      end

      send_single(last, flags) if last
    end

    def send_single(message, flags)
      zmqmsg = RbZMQ::Message.new(message).to_zmq
      ZMQError.error! zmq_socket.sendmsg(zmqmsg, flags)
    end

    # Convert option hash to ZMQ flag list
    # * :block (! DONTWAIT) defaults to true
    # * :more (SNDMORE) defaults to false
    def convert_flags(opts, flags = 0, allowed = [:block, :more])
      if !opts.fetch(:block, true) && allowed.include?(:block)
        flags |= ZMQ::DONTWAIT
      end
      if opts.fetch(:more, false)  && allowed.include?(:more)
        flags |= ZMQ::SNDMORE
      end

      flags
    end

    def poll
      @poll ||= RbZMQ::Poller.new.tap do |poll|
        poll.register @zmq_socket, ZMQ::POLLIN
      end
    end

    # RECV timeout using ZMQ::POLLER
    def with_recv_timeout(opts)
      timeout = parse_timeout opts[:timeout]

      unless poll.poll(timeout){ return yield }
        raise Errno::EAGAIN.new "ZMQ socket did not receive anything " \
                                "within #{timeout}ms."
      end
    end

    def parse_timeout(timeout)
      case timeout
        when :blocking, :infinity
          -1
        when nil
          DEFAULT_TIMEOUT
        else
          Integer(timeout)
      end
    end
  end
end

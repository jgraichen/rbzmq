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

    # @!visibility private
    #
    # Message class.
    #
    attr_reader :message_class

    # Allocates a socket of given type for sending and receiving data.
    #
    # @param type [Integer] ZMQ socket type, on if ZMQ::REQ, ZMQ::REP,
    #   ZMQ::PUB, ZMQ::SUB, ZMQ::PAIR, ZMQ::PULL, ZMQ::PUSH,
    #   ZMQ::XREQ, ZMQ::REP, ZMQ::DEALER or ZMQ::ROUTER.
    #
    # @param opts [Hash] Option hash. :ctx will be removed, all other
    #   options will be passed to ZMQ::Socket.new.
    #
    # @option opts [Class] :receiver_class By default ZMQ::ManagedMessage
    #   is used for automatic memory management. For manual memory management
    #   override with ZMQ::Message.
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
      opts = {receiver_class: ZMQ::ManagedMessage}.merge opts

      ctx = opts.fetch(:ctx) { RbZMQ::Context.global }
      ctx = ctx.pointer if ctx.respond_to? :pointer

      unless ctx.is_a?(FFI::Pointer)
        raise ArgumentError.new "Context must be ZMQ::Context or " \
          "RbZMQ::Context (respond to #pointer) or must be a FFI::Pointer, "\
          "but #{ctx.inspect} given."
      end

      @zmq_ctx       = ctx
      @zmq_socket    = ZMQ::Socket.new ctx, type
      @message_class = opts[:receiver_class]
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
    # @return [RbZQM::Socket] Self.
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

    # Queues the message for transmission.
    #
    # @example
    #   begin
    #     socket.send_msg message
    #   rescue RbZMQ::ZMQError => err
    #     puts 'Send failed.'
    #   end
    #
    # @param message [ZMQ::Message] Message to send. Message is
    #   assumed to conform to the same public API as ZMQ::Message.
    #
    # @param flags [Integer] May contains of the following flags:
    #   * 0 (default) - blocking operation
    #   * ZMQ::DONTWAIT - non-blocking operation
    #   * ZMQ::SNDMORE - this message is part of a multi-part message
    #
    # @param opts [Hash] Options.
    #
    # @option opts [Boolean] :block If method call should block. Will set
    #   ZMQ::DONTWAIT flag if false. Defaults to true.
    #
    # @option opts [Boolean] :more If message is part of a multipart message.
    #   Set ZMQ::SNDMORE flag if true. Defaults to false.
    #
    # @option opts [Boolean] :close If given message should be closed after
    #   sending. If true message will also be closed on error. Defaults to
    #   false.
    #
    # @raise [ZMQError] Raises an error under two conditions:
    #   1. The message could not be enqueued
    #   2. When flags is set with ZMQ::DONTWAIT and the socket
    #      returned EAGAIN.
    #
    # @return [Boolean] True.
    #
    def send_msg(message, flags = 0, opts = {})
      opts, flags = flags, 0 if flags.is_a?(Hash)

      rc = zmq_socket.sendmsg message,
                              convert_flags(opts, flags, [:more, :block])
      ZMQError.error! rc
      true
    ensure
      message.close if opts.fetch(:close, false)
    end

    # Queues given messages for transmission.
    #
    # @example
    #   begin
    #     socket.send_msgs message, another_message
    #   rescue RbZMQ::ZMQError => err
    #     puts 'Send failed.'
    #   end
    #
    # @param messages [Array<ZMQ::Message>] Messages to send. Each message is
    #   assumed to conform to the same public API as ZMQ::Message.
    #
    # @param flags [Integer] May contains of the following flags:
    #   * 0 (default) - blocking operation
    #   * ZMQ::DONTWAIT - non-blocking operation
    #   * ZMQ::SNDMORE - this message is part of a multi-part message
    #   If SNDMORE is set or :more option is given the last message will also
    #   be send with SNDMORE.
    #
    # @param opts [Hash] Options.
    #
    # @option opts [Boolean] :block If method call should block. Will set
    #   ZMQ::DONTWAIT flag if false. Defaults to true.
    #
    # @option opts [Boolean] :more If true last message will also be send with
    #   ZMQ::SNDMORE. Defaults to false.
    #
    # @option opts [Boolean] :close If given messages should be closed after
    #   sending. If true messages will also be closed on error. Defaults to
    #   false.
    #
    # @raise [ZMQError] Raises an error under two conditions:
    #   1. A message could not be enqueued
    #   2. When flags is set with ZMQ::DONTWAIT and the socket
    #      returned EAGAIN.
    #
    # @return [Boolean] True.
    #
    def send_msgs(messages, flags = 0, opts = {})
      opts, flags = flags, 0 if flags.is_a?(Hash)
      flags       = convert_flags opts, flags

      messages[0..-2].each{|m| send_msg(m, flags | ZMQ::SNDMORE) }
      send_msg messages.last, flags

      true
    ensure
      messages.each(&:close) if opts.fetch(:close, false)
    end

    # Helper method to make a new Message instance out of the string passed
    # in for transmission.
    #
    # @example
    #   socket.send_string "Hello World!"
    #
    # @param string [String] String to send. Will be used to create
    #   a ZMQ::Message.
    #
    # @param flags [Integer] See {#send_msg} for allowed flags.
    #
    # @param opts [Hash] Options. See {#send_msg} for allowed options.
    #
    # @raise [ZMQError] See {#send_msg} for raised error.
    #
    # @return [Boolean] True.
    #
    def send_string(string, flags = 0, opts = {})
      send_msg ZMQ::Message.new(string), flags, opts.merge(close: true)
    end

    # Send a sequence of strings as a multipart message out of the parts
    # passed in for transmission.
    #
    # @example
    #   socket.send_strings ["Hello", "World!"]
    #
    # @param strings [Array<String>] Strings to send as multipart message.
    #
    # @param flags [Integer] See {#send_msgs} for allowed flags.
    #
    # @param opts [Hash] Options. See {#send_msgs} for allowed options.
    #
    # @raise [ZMQError] See {#send_msgs} for raised errors.
    #
    # @return [Boolean] True.
    #
    def send_strings(strings, flags = 0, opts = {})
      send_msgs strings.map{|str| ZMQ::Message.new str },
                flags,
                opts.merge(close: true)
    end

    # Dequeues a message from the underlying queue. By default, this is a
    # blocking operation.
    #
    # @example
    #   message = socket.recv_msg
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
    #   to {DEFAULT_TIMEOUT}. The values :blocking, :infinity or -1 will
    #   wait forever.
    #
    # @raise [ZMQError] Raise error under two conditions.
    #   1. The message could not be dequeued
    #   2. When mode is non-blocking and the socket returned EAGAIN.
    #
    # @raise [Errno::EAGAIN] When timeout was reached without receiving
    #   a message.
    #
    # @return [ZMQ::Message] Return an object of
    #
    def recv_msg(flags = 0, opts = {})
      opts, flags = flags, 0 if flags.is_a?(Hash)

      with_recv_timeout(opts) do
        rc = zmq_socket.recvmsg((message = create_message),
                                convert_flags(opts, flags, [:block]))
        ZMQError.error! rc
        message
      end
    end

    # Helper method to make a new #Message instance and convert its payload
    # to a string.
    #
    # @example
    #   str = socket.recv_string
    #
    # @param flags [Integer] May be ZMQ::DONTWAIT.
    #
    # @param opts [Hash] Options.
    #
    # @raise [ZMQError] Raises error under two conditions:
    #   1. The message could not be dequeued
    #   2. When non-blocking and the socket returned EAGAIN.
    #
    # @return [String] Received string.
    #
    def recv_string(flags = 0, opts = {})
      opts, flags = flags, 0 if flags.is_a?(Hash)

      with_recv_timeout(opts) do
        rc = zmq_socket.recv_string((str = ''),
                                    convert_flags(opts, flags, [:block]))
        ZMQError.error! rc
        str
      end
    end

    private

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

    # Create new empty message
    def create_message
      message_class.new
    end

    def poll
      @poll ||= ZMQ::Poller.new.tap do |poll|
        poll.register @zmq_socket, ZMQ::POLLIN
      end
    end

    # RECV timeout using ZMQ::POLLER
    def with_recv_timeout(opts)
      timeout = parse_timeout opts[:timeout]

      ZMQError.error! poll.poll timeout
      if poll.readables.any?
        yield
      else
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

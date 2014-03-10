module RbZMQ

  class Socket

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
    # @param address [String] Address to bind. Must be a supported protocol.
    #
    # @raise [ZMQError] On error.
    #
    # @return [Boolean] True.
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
    # @return [Boolean] True.
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
      opts, flags = flags, 0 if Hash === flags

      ZMQError.error! zmq_socket.sendmsg message, convert_flags(opts, flags, [:more, :block])
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
      opts, flags = flags, 0 if Hash === flags
      flags       = convert_flags opts, flags

      messages[0..-2].each{|m| send_msg m, flags | ZMQ::SNDMORE }
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
    # @param flags [Integer] See {#sendmsg} for flags.
    #
    # @raise [ZMQError] See {#sendmsg} for raised error.
    #
    # @return [Boolean] True.
    #
    def send_string(string, flags = 0)
      ZMQError.error! zmq_socket.send_string string, flags
    end

    # Send a sequence of strings as a multipart message out of the parts
    # passed in for transmission.
    #
    # @overload send_strings(str1, str2, ..., flags = 0)
    #
    #   @example
    #     socket.send_strings "Hello", "World!"
    #
    #   @param str1, str2, ... [String] Strings to send as multipart message.
    #
    # @overload send_strings(strings, flags = 0)
    #
    #   @example
    #     socket.send_strings ["Hello", "World!"]
    #
    #   @param strings [Array<String>] Strings to send as multipart message.
    #
    # @param flags [Integer] May be ZMQ::DONTWAIT.
    # @raise [ZMQError] Raise an error under two conditions.
    #   1. A message could not be enqueued
    #   2. When ZMQ::DONTWAIT was given and the socket returned EAGAIN.
    #
    # @return [Boolean] True.
    #
    def send_strings(*args)
      args  = args.flatten
      flags = (Integer === args.last) ? args.pop : 0
      ZMQError.error! zmq_socket.send_strings args, flags
    end

    private
    # Convert option hash to ZMQ flag list
    # * :block (! DONTWAIT) defaults to true
    # * :more (SNDMORE) defaults to false
    def convert_flags(opts, flags = 0, allowed = [:block, :more])
      flags = flags | ZMQ::DONTWAIT if !opts.fetch(:block, true) && allowed.include?(:block)
      flags = flags | ZMQ::SNDMORE  if opts.fetch(:more, false) && allowed.include?(:more)
      flags
    end
  end
end

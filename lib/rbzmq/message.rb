module RbZMQ
  #
  # = RbZMQ::Message
  #
  class Message

    attr_reader :data

    def initialize(str = '')
      if str.is_a?(ZMQ::Message)
        @data = str.copy_out_string
        str.close
      else
        @data = str.to_s
      end
    end

    def to_s
      data
    end

    def to_zmq
      ZMQ::Message.new(data)
    end

    class << self

      # Create new {RbZMQ::Message}.
      #
      # If first argument is a {RbZMQ::Message} object it will
      # be returned instead of a new one.
      #
      # @return [RbZMQ::Message] Newly created message.
      #
      def new(*args)
        return args[0] if args[0].is_a?(self)
        super
      end
    end
  end
end

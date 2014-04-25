module RbZMQ
  #
  # = RbZMQ::Message
  #
  class Message
    #
    attr_reader :data, :next

    def initialize(str = '', nxt = nil)
      if str.is_a?(ZMQ::Message)
        @data = str.copy_out_string
        str.close
      else
        @data = str.to_s
      end

      @next = nxt
    end

    def to_s
      data
    end

    def to_zmq
      ZMQ::Message.new(data)
    end

    def more?
      !@next.nil?
    end

    def each
      return to_enum(:each) unless block_given?

      yield(node = self)
      yield node while (node = node.next)
    end

    class << self
      #
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

      def from_zmq(messages)
        messages.reverse.reduce(nil) do |memo, msg|
          RbZMQ::Message.new(msg, memo)
        end
      end
    end
  end
end

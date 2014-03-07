module RbZMQ

  class Context
    # @!visibility private
    #
    # Internal {ZMQ::Context} reference.
    #
    attr_reader :zmq_ctx

    # Create new context.
    #
    def initialize(opts = {})
      @zmq_ctx = opts.delete(:context) { self.class.global }
    end

    # Return {FFI::Pointer} from {ZMQ::Context}.
    #
    # @return [FFI::Pointer] return
    def pointer
      zmq_ctx.pointer
    end

    class << self

      # Return a process global ZMQ context that will be
      # lazy initialized on first request.
      #
      # @return [ZMQ::Context]
      #
      def global
        unless @zmq_ctx && @ctx_pid == Process.pid
          @zmq_ctx = ZMQ::Context.new
          @ctx_pid = Process.pid
        end

        @zmq_ctx
      end
    end
  end
end

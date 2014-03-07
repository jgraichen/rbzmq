module RbZMQ

  class Error < StandardError
    # noop
  end

  class ZMQError < Error
    attr_reader :rc, :errno, :message

    def initialize(rc, errno = nil, message = nil)
      if ZMQ::ZeroMQError === rc
        @rc      = rc.result_code
        @errno   = rc.error_code
        @message = rc.message =~ /msg\s+\[(.*?)\]/ ? $1 : 'Unknown'
      else
        @rc      = rc
        @errno   = errno || ZMQ::Util.errno
        @message = message || ZMQ::Util.error_string
      end

      super "[ERRNO #{@errno}, RC #{@rc}] #{@message}"
    end

    alias_method :error_code, :errno
    alias_method :result_code, :rc

    class << self
      def error!(rc)
        if error?(rc)
          raise new(rc)
        else
          true
        end
      end

      def error?(rc)
        -1 == rc
      end

      def ok?(rc)
        !error? rc
      end
    end
  end
end

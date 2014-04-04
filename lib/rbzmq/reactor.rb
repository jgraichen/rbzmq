require 'concurrent/obligation'

module RbZMQ
  #
  class Reactor
    #
    # Default select timeout in seconds.
    #
    DEFAULT_TIMEOUT = 10_000

    def initialize
      @poller = RbZMQ::Poller.new
      @queue  = Queue.new

      @queue << Proc.new if block_given?

      @thread = Thread.new { run_loop }
    end

    def watch(io, interest, &block)
      poller.register(io, interest)
      cb[io]
    end

    def run(&block)
      @queue << block
      @selector.wakeup
    end

    def timeout
      @timeout || DEFAULT_TIMEOUT
    end

    def close
      @close = true
      @selector.wakeup
      @selector.close
    end

    private

    attr_reader :poller, :cb

    def run_loop
      loop do
        if @close
          break
        else
          run
        end
      end
    rescue => err
      $stderr.warn "RbZMQ::Reactor crashed: #{err}: \n"\
                   "#{err.backtrace.join("\n")}"
    end

    def run
      process
      select
    end

    def process
      while (block = @queue.pop(true))
        begin
          instance_eval(&block)
        rescue => err
          $stderr.warn "RbZMQ::Reactor run block crashed: #{err}: \n"\
                       "#{err.backtrace.join("\n")}"
        end
      end
    rescue ThreadError
      nil
    end

    def select
      puts "Reactor selecting (#{timeout})..."
      @selector.select(timeout) do |monitor|
        begin
          monitor.value.call
        rescue => err
          $stderr.warn "RbZMQ::Reactor select block crashed: #{err}: \n"\
                       "#{err.backtrace.join("\n")}"
        end
      end
    end

    #
    class Future
      include Concurrent::Obligation
    end
  end
end

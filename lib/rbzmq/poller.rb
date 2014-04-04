module RbZMQ
  #
  # = RbZMQ::Poller
  #
  # The {Poller} allows to poll on one or more ZMQ sockets
  # or file descriptors simultaneously.
  #
  # @example
  #   poller = RbZMQ::Poller.new
  #   poller.register(socket, ZMQ::POLLIN)
  #   poller.poll(10_000) do |socket|
  #     # Do something with socket
  #   end
  #
  class Poller
    #
    # Create a new poller.
    #
    def initialize
      @poll_items = ZMQ::PollItems.new
      @mutex      = Mutex.new
    end

    # Poll on all registered objects.
    #
    # If a block is given it will be invoked for each ready
    # pollable object. Without a block an enumerator of
    # ready pollables will be returned.
    #
    # If not selectable is registered {#poll} will return
    # without blocking.
    #
    # @example Poll with block
    #   poller.poll(10_000) do |io|
    #     io.readable? || io.writable? #=> true
    #   end
    #
    # @param timeout [Integer, Symbol] A timeout in milliseconds.
    #   The values `-1`, `:blocking` and `:infinity` will
    #   block indefinitely.
    #
    # @yield [pollable] Yield each ready object.
    # @yieldparam pollable [RbZMQ::Socket, IO, Object] Registered
    #   pollable object.
    #
    # @return [Enumerator, Boolean, Nil] The return value is
    #   determined by the following rules:
    #   1. Nil is returned when no objects are registered.
    #   2. An Enumerator will be returned when no block
    #      is given. The enumerator will have no elements if
    #      call timed out.
    #   3. If a block is given true will be returned when
    #      objects were ready, false if times out.
    #
    def poll(timeout, &block)
      mutex.synchronize do
        if @poll_items.any?
          ready_items = do_poll(convert_timeout(timeout))

          if block_given?
            ready_items > 0 ? each_ready_item(&block) : false
          else
            if ready_items > 0
              to_enum(:each_ready_item)
            else
              Array.new.to_enum(:each)
            end
          end
        else
          nil
        end
      end
    end

    # Return number of registered pollables.
    #
    # @return [Integer] Number of registered objects.
    #
    def size
      mutex.synchronize { @poll_items.size }
    end

    # Register given socket or IO to be watched on given
    # event list.
    #
    # This method is idempotent.
    #
    # @example Watch socket to read
    #   socket = RbZMQ::Socket.new(ZMQ::DEALER)
    #   poller.register(socket, ZMQ::POLLIN)
    #
    # @example Watch IO to write
    #   reader, writer = IO.pipe
    #   poller.register(writer, ZMQ::POLLOUT)
    #
    # @param pollable [RbZMQ::Socket, IO] Watchable socket or
    #   IO object.
    #
    # @param events [Integer] ZMQ events. Calling multiple
    #   times with different events will OR the events together.
    #   Allowed values are ZMQ::POLLIN and ZMQ::POLLOUT.
    #
    # @return [Integer] Registered events for pollable.
    #
    def register(pollable, events = ZMQ::POLLIN)
      return if pollable.nil? || events.zero?

      mutex.synchronize do
        item = @poll_items[pollable]
        unless item
          item = ::ZMQ::PollItem.from_pollable(pollable)
          @poll_items << item
        end

        item.events |= events
      end
    end

    # Deregister events from pollable.
    #
    # When no events are left or socket or IO object has been
    # closed it will also be remove from watched objects.
    #
    # @param pollable [RbZMQ::Socket, IO] Watchable socket
    #  or IO object.
    #
    # @param events [Integer] ZMQ events.
    #   Allowed values are ZMQ::POLLIN and ZMQ::POLLOUT.
    #
    # @return [Boolean] False if pollable was removed
    #   because all events where removed or it was closed,
    #   nil if pollable was not registered or an Integer
    #   with the leaving events.
    #
    def deregister(pollable, events = ZMQ::POLLIN | ZMQ::POLLOUT)
      return unless pollable

      mutex.synchronize do
        item = @poll_items[pollable]
        if item && (item.events & events) > 0
          item.events ^= events

          if item.events.zero? || item.closed?
            @poll_items.delete pollable
            false
          else
            item.events
          end
        else
          nil
        end
      end
    end

    # Remove socket or IO object from poller.
    #
    # @param pollable [RbZMQ::Socket, IO] Watched object to remove.
    #
    # @return [Boolean] True if pollable was successfully
    #   removed, false otherwise.
    #
    def delete(pollable)
      mutex.synchronize do
        return false if @poll_items.empty?

        @poll_items.delete pollable
      end
    end

    private

    attr_reader :mutex

    def do_poll(timeout)
      rc = LibZMQ.zmq_poll @poll_items.address,
                           @poll_items.size,
                           timeout
      RbZMQ::ZMQError.error! rc
    end

    def each_ready_item(&block)
      @poll_items.each do |item|
        yield item.pollable if item.readable? || item.writable?
      end

      true
    end

    def convert_timeout(timeout)
      case timeout
        when :blocking, :infinity, -1
          -1
        else
          Integer timeout
      end
    end
  end
end

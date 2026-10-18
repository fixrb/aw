# frozen_string_literal: true

require_relative "child_error"

module Aw
  # The fork itself: one child, one pipe, one marshaled message back.
  #
  # The child runs the block and writes `[:return, value]`, `[:raise,
  # exception]` or, when neither can be marshaled, `[:opaque, description]`
  # to the pipe as a length-prefixed `Marshal` message, then leaves with
  # `exit!`. The parent reads the message, reaps the child, and demands
  # both a decodable message and a successful exit status.
  #
  # @api private
  module Fork
    HEADER = "Q>"
    HEADER_SIZE = 8
    CHUNK = 65_536

    # Exit status of a child that failed to deliver, as opposed to a block
    # that called `exit!` itself. EX_SOFTWARE in sysexits(3).
    FAILURE = 70
    LEFT = "the block left without returning or raising (break, return or throw), " \
           "so the child delivered no result"

    # Captured once, so that a block redefining `Process.exit!` in the child
    # cannot make the child fall through to the parent's `at_exit` handlers.
    EXIT = ::Process.method(:exit!)

    private_constant :HEADER, :HEADER_SIZE, :CHUNK, :FAILURE, :LEFT, :EXIT

    # @param block [Proc] the code to run in the child
    # @return [Array(Symbol, Object)] `[:return, value]` or `[:raise, exception]`
    # @raise [NotImplementedError] when this Ruby cannot fork
    # @raise [Aw::ChildError] when no result came back
    def self.run(block)
      raise ::NotImplementedError, "fork(2) is not available on this Ruby" unless Aw.supported?

      # Binary: no transcoding of the message, whatever the default encodings.
      reader, writer = ::IO.pipe(binmode: true)
      pid = nil
      # No interruption of the parent, not even a Thread#kill, between the
      # fork and the ensure that reaps the child. The child lifts the mask
      # again, see `child`.
      ::Thread.handle_interrupt(::Object => :never) do
        pid = ::Process.fork { child(block, reader, writer) }
        writer.close
      end
      data = read(reader)
      _, status = ::Process.wait2(pid)
      pid = nil

      deliver(data, status)
    ensure
      [writer, reader].each { |io| io&.close }
      reap(pid)
    end

    # Never returns: the child writes its result and leaves with `exit!`,
    # whatever the block does, including a `break`, a `return` or a `throw`,
    # which the ensure catches too. The interrupt mask inherited from the
    # parent is lifted first, so that a `Timeout` or a signal inside the
    # block behaves as usual. The child is blocking: a fiber scheduler the
    # parent set does not see the block, which would otherwise hand the
    # child over to the parent's other fibers.
    def self.child(block, reader, writer)
      ::Fiber.blocking do
        ::Thread.handle_interrupt(::Object => :immediate) do
          reader.close
          data = dump(evaluate(block))
          writer.write([data.bytesize].pack(HEADER), data)
          leave(0)
        ensure
          leave(FAILURE)
        end
      end
    end

    # Flushes the standard streams of the child and leaves with the status.
    # The exit is in an ensure of its own, so that a `throw` from the
    # `flush` of a stream the block replaced cannot skip it.
    def self.leave(status)
      flush
    ensure
      EXIT.call(status)
    end

    # Calls the block and tells how it ended: `[:return, value]` or
    # `[:raise, exception]`.
    def self.evaluate(block)
      [:return, block.call]
    rescue ::Exception => e # rubocop:disable Lint/RescueException
      [:raise, e]
    end

    # Marshals the message or, when it cannot be marshaled, a description
    # of it.
    def self.dump(message)
      ::Marshal.dump(message)
    rescue ::Exception => e # rubocop:disable Lint/RescueException
      ::Marshal.dump([:opaque, opaque(message, e)])
    end

    # A description of what could not be transferred, built defensively:
    # the value comes from the block and its methods may raise.
    def self.opaque(message, error)
      kind, value = message
      label = value.class.name || "an anonymous class"
      subject = kind == :raise ? "raised #{label} (#{value.message})" : "returned an instance of #{label}"
      "the block #{subject}, which cannot be transferred from the child: #{error.message}"
    rescue ::Exception # rubocop:disable Lint/RescueException
      "the block #{kind == :raise ? "raised" : "returned"} something that cannot be transferred from the child"
    end

    # Flushes the standard streams of the child. A stream the block closed or
    # replaced may not flush: that must not cost the result.
    def self.flush
      [$stdout, $stderr].each do |stream|
        stream.flush
      rescue ::Exception # rubocop:disable Lint/RescueException
        nil
      end
    end

    # Reads the announced number of bytes, chunk by chunk so that a corrupt
    # header cannot make the parent allocate a huge buffer at once.
    #
    # @return [String, nil] the message, or nil when it is missing or short
    def self.read(reader)
      header = reader.read(HEADER_SIZE)
      return nil if header.nil? || header.bytesize < HEADER_SIZE

      size = header.unpack1(HEADER)
      data = ::String.new
      while data.bytesize < size
        chunk = reader.read([size - data.bytesize, CHUNK].min)
        return nil if chunk.nil?

        data << chunk
      end
      data
    end

    # Returns `[kind, value]` from a child that delivered a result and
    # exited normally; raises a ChildError that says why otherwise.
    def self.deliver(data, status)
      raise ChildError.new(LEFT, status:) if status.exitstatus == FAILURE
      raise ChildError.new("the child did not deliver a result", status:) unless status.success? && data

      kind, value = load(data, status)
      raise ChildError.new(value, status:) if kind == :opaque

      [kind, value]
    end

    # Loads the message and accepts only the three forms the child writes, as
    # arrays: a Struct or a Data with the same members is refused. What
    # `Marshal.load` raises, short of an interruption, is a ChildError, never
    # an exception of the block: a `marshal_load` of the parent, an autoload,
    # a structure too deep or too large for the parent.
    def self.load(data, status)
      message = ::Marshal.load(data) # rubocop:disable Security/MarshalLoad
    rescue ::StandardError, ::ScriptError, ::SystemStackError, ::NoMemoryError => e
      raise ChildError.new("the child delivered an undecodable message (#{e.message})", status:)
    else
      case message
      in ::Array[:return, _] | ::Array[:raise, ::Exception] then message
      in ::Array[:opaque, ::String => text] if text.encoding.ascii_compatible? then message # rubocop:disable Lint/DuplicateBranch
      else raise ChildError.new("the child delivered an unexpected message", status:)
      end
    end

    # Reaps a child the parent gave up waiting for, killing it first if it
    # is still running. The child is checked before being killed: a wait2
    # interrupted right after it reaped would otherwise lead to a kill on a
    # pid that may already belong to another process.
    def self.reap(pid)
      return if pid.nil?
      return if ::Process.wait2(pid, ::Process::WNOHANG)

      ::Process.kill(:KILL, pid)
      ::Process.wait(pid)
    rescue ::Errno::ESRCH, ::Errno::ECHILD
      nil
    end

    private_class_method :child, :leave, :evaluate, :dump, :opaque, :flush, :read, :deliver, :load, :reap
  end
end

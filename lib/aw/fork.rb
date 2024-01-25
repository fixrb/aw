# frozen_string_literal: true

require "English"

module Aw
  # The Fork class.
  #
  # @api private
  class Fork
    # Initialize the class.
    #
    # @param read  [IO] The read endpoint.
    # @param write [IO] The write endpoint.
    def initialize(read, write)
      # Currently, not available on all platforms.
      raise ::NotImplementedError, "fork()" unless ::Process.respond_to?(:fork)

      @read   = read
      @write  = write
    end

    # @!attribute [r] read
    #
    # @return [IO] The read endpoint.
    attr_reader :read

    # @!attribute [r] write
    #
    # @return [IO] The write endpoint.
    attr_reader :write

    # Runs the block inside a sub-process, and returns the computed value.
    #
    # @example Computes `6 * 7` in a sub-process and returns `42` to the current process.
    #   call { 6 * 7 } # => 42
    #
    # @raise [Exception] Exceptions raised in a block of code are propagated.
    # @return [#object_id] Returns the value that has been returned in the block.
    def call(&)
      pid = fork_and_return_pid(&)
      write.close
      result = read.read
      ::Process.wait(pid)

      # rubocop:disable Security/MarshalLoad
      ::Marshal.load(result).tap { |r| raise r if r.is_a?(::Exception) }
      # rubocop:enable Security/MarshalLoad
    end

    private

    # Creates a sub-process to execute a block inside, and returns the
    # sub-process ID.
    #
    # @return [Integer] The ID of the created sub-process.
    def fork_and_return_pid
      ::Process.fork do
        # :nocov:

        read.close

        # rubocop:disable Lint/RescueException
        begin
          result = yield
        rescue ::Exception
          result = $ERROR_INFO
        end
        # rubocop:enable Lint/RescueException

        ::Marshal.dump(result, write)
        ::Process.exit!(true)

        # :nocov:
      end
    end
  end
end

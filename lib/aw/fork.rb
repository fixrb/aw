# frozen_string_literal: true

require 'English'

module Aw
  # The Fork class.
  class Fork
    # Initialize the class.
    #
    # @param read  [IO] The read endpoint.
    # @param write [IO] The write endpoint.
    def initialize(read, write)
      # Currently, not available on all platforms.
      raise NotImplementedError, 'fork()' unless ::Process.respond_to?(:fork)

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

    # Run the block inside a subprocess, and return the value.
    #
    # @return [#object_id] The result.
    def call(*, **, &block)
      pid = fork_and_return_pid(&block)
      write.close
      result = read.read
      ::Process.wait(pid)

      # rubocop:disable MarshalLoad
      ::Marshal.load(result).tap do |r|
        raise r if r.is_a?(::Exception)
      end
      # rubocop:enable MarshalLoad
    end

    private

    def fork_and_return_pid
      fork do
        read.close

        # rubocop:disable Lint/RescueException
        begin
          result = yield
        rescue ::Exception
          result = $ERROR_INFO
        end
        # rubocop:enable Lint/RescueException

        ::Marshal.dump(result, write)
        exit!(0)
      end
    end
  end
end

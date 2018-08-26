# frozen_string_literal: true

module Aw
  # The Fork class.
  class Fork
    # Initialize the class.
    #
    # @param read  [IO] The read endpoint.
    # @param write [IO] The write endpoint.
    def initialize(read, write)
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
    def call
      pid = fork do
        read.close
        result = yield
        Marshal.dump(result, write)
        exit!(0)
      end

      write.close
      result = read.read
      Process.wait(pid)

      # rubocop:disable MarshalLoad
      Marshal.load(result)
      # rubocop:enable MarshalLoad
    end
  end
end

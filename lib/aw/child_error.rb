# frozen_string_literal: true

module Aw
  # Raised in the parent when the child process did not deliver a result:
  # it was killed, it exited on its own, the block left without returning
  # or raising, what the block returned or raised cannot be marshaled, or
  # the parent cannot load it (an instance of a class it does not know, or
  # a `marshal_load` that raises).
  #
  # The status tells the cases apart: `signaled?` for a crash, `exitstatus`
  # 70 for a block that left without returning or raising, 74 for a result
  # the child could not write because the block closed the pipe, 0 for a
  # result that cannot be transferred or loaded, the block's own code for an
  # `exit!` or an `exec` of the block.
  class ChildError < ::StandardError
    # @return [Process::Status] the status of the child
    attr_reader :status

    # @param message [String]
    # @param status [Process::Status]
    def initialize(message, status:)
      @status = status
      super("#{message} (#{status})")
    end
  end
end

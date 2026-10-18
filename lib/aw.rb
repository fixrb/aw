# frozen_string_literal: true

require_relative "aw/child_error"
require_relative "aw/fork"

# Runs a block in a forked child process and brings back what it returned,
# or re-raises what it raised. Side effects of the block on the process
# (mutations, globals, constants, the current directory, `ENV`, a crash)
# stay in the child; what it does outside, to files or to other processes,
# does not.
#
# The result travels through a pipe with `Marshal`, so it must be a
# marshalable value; a `Proc`, an `IO` or an instance of an anonymous class
# cannot come back. `fork(2)` is required: Windows, JRuby and any other
# implementation without it are not supported, and {Aw.supported?} says so.
#
# @example
#   list = []
#   Aw.fork! { list << 1 } # => [1]
#   list                   # => []
module Aw
  # @return [Boolean] whether this Ruby can fork
  def self.supported?
    ::Process.respond_to?(:fork)
  end

  # Runs the block in a child process and returns its value.
  #
  # @yieldreturn [Object] a marshalable value
  # @return [Object] the value returned by the block, loaded from the child
  # @raise [ArgumentError] when no block is given
  # @raise [NotImplementedError] when this Ruby cannot fork
  # @raise [Exception] whatever the block raised, re-raised in the parent
  # @raise [Aw::ChildError] when the child delivered no result (it died, the block called `exit!` or
  #   left with `break`, `return` or `throw`), or its result cannot be transferred or loaded
  def self.fork!(&block)
    raise ::ArgumentError, "a block must be provided" if block.nil?

    kind, value = Fork.run(block)
    # The cause is the one the exception had in the child, never the
    # exception the parent may be handling.
    raise value, cause: value.cause if kind == :raise

    value
  end

  # Runs the block in a child process and tells whether it returned.
  #
  # Only what happens in the child is reported: an exception raised in the
  # parent while waiting, such as an `Interrupt` or a `Timeout::Error`,
  # propagates. Neither the value nor the exception of the block travels,
  # so this works whatever they are.
  #
  # @yieldreturn [Object] ignored
  # @return [Boolean] true when the block returned, false when it raised
  # @raise [ArgumentError] when no block is given
  # @raise [NotImplementedError] when this Ruby cannot fork
  # @raise [Aw::ChildError] when the child died, or the block called `exit!` or left with `break`,
  #   `return` or `throw`
  def self.fork?(&block)
    raise ::ArgumentError, "a block must be provided" if block.nil?

    returned = lambda do
      yield
      true
    rescue ::Exception # rubocop:disable Lint/RescueException
      false
    end

    _, value = Fork.run(returned)
    value.equal?(true)
  end
end

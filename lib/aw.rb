# frozen_string_literal: true

# Namespace for the Aw library.
#
# @example Computes `6 * 7` in a sub-process and returns `42` to the current process.
#   Aw.fork! { 6 * 7 } # => 42
#
# @example Computes `6 * 7` in a sub-process and returns `true` to the current process if no exception is thrown.
#   Aw.fork? { 6 * 7 } # => true
#
# @api public
module Aw
  # Runs the block inside a sub-process, and returns the computed value.
  #
  # @example Computes `6 * 7` in a sub-process and returns `42` to the current process.
  #   Aw.fork! { 6 * 7 } # => 42
  #
  # @example Computes `nil + 1` in a sub-process and raises `NoMethodError` to the current process.
  #   Aw.fork! { nil + 1 } # => raise NoMethodError (undefined method `+' for nil:NilClass)
  #
  # @raise [Exception] Exceptions raised in a block of code are propagated.
  # @return [#object_id] Returns the value that has been returned in the block.
  def self.fork!(&)
    read, write = ::IO.pipe
    Fork.new(read, write).call(&)
  end

  # Runs the block inside a sub-process, and returns `true` if no exception is
  # thrown. Otherwise when an exception is raised, `false` is returned.
  #
  # @example Computes `6 * 7` in a sub-process and returns `true` to the current process.
  #   Aw.fork? { 6 * 7 } # => true
  #
  # @example Computes `nil + 1` in a sub-process and returns `false` to the current process.
  #   Aw.fork? { nil + 1 } # => false
  #
  # @return [Boolean] Returns `true` if stat is successful, `false` if not.
  def self.fork?(&)
    pid = ::Process.fork(&)
    _, status = ::Process.wait2(pid)
    status.success?
  end
end

require_relative File.join("aw", "fork")

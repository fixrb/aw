# frozen_string_literal: true

# Namespace for the Aw library.
#
# @example Computes `6 * 7` in a sub-process and returns `42` to the current process.
#   Aw.fork! { 6 * 7 } # => 42
#
# @api public
module Aw
  # Runs the block inside a sub-process, and returns the computed value.
  #
  # @param block [Proc] The code to run in a sub-process.
  #
  # @example Computes `6 * 7` in a sub-process and returns `42` to the current process.
  #   fork! { 6 * 7 } # => 42
  #
  # @return [#object_id] The computed value.
  def self.fork!(&block)
    read, write = ::IO.pipe
    Fork.new(read, write).call(&block)
  end
end

require_relative File.join("aw", "fork")

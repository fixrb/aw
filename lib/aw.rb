# frozen_string_literal: true

# Namespace for the Aw library.
#
# @api public
#
# @example Fork and return 42 from 6 * 7.
#   Aw.fork! { 6 * 7 } # => 42
module Aw
  # Run the block inside a subprocess, and return the value.
  #
  # @param block [Proc] The code to run in a subprocess.
  #
  # @return [#object_id] The result.
  def self.fork!(&block)
    Fork.new(*IO.pipe).call(&block)
  end
end

require_relative File.join 'aw', 'fork'

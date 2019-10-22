# frozen_string_literal: true

require_relative File.join 'support', 'coverage'
require_relative File.join '..', 'lib', 'aw'

# It is expected to equal 42
raise unless 42.equal?(Aw.fork! { 6 * 7 })

# It is expected to eql 'bar'
raise unless 'bar'.eql?(Aw.fork! { 'bar' })

# It is expected to be nil
raise unless (Aw.fork! {}).nil?

# It is expected to raise
begin
  Aw.fork! { raise "an exception" }
rescue
  raise unless $!.message == 'an exception'
end

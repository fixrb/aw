# frozen_string_literal: true

require_relative File.join('support', 'coverage')
require_relative File.join('..', 'lib', 'aw')

# It is expected to equal 42
raise unless 42.equal?(Aw.fork! { 6 * 7 })

# It is expected to eql 'bar'
raise unless 'bar'.eql?(Aw.fork! { 'bar' })

# It is expected to be nil
raise unless (Aw.fork! {}).nil?

# It is expected to raise a generic error
begin
  Aw.fork! { raise 'BOOM' }
rescue RuntimeError
  raise unless $ERROR_INFO.message == 'BOOM'
end

# It is expected to initiate the termination of the script
begin
  Aw.fork! { exit(1) }
rescue SystemExit
  raise unless $ERROR_INFO.message == 'exit'
end

require_relative File.join 'support', 'coverage'
require_relative File.join '..', 'lib', 'aw'

# It is expected to equal 42
fail unless 42.equal? Aw.fork! { 6 * 7 }

# It is expected to eql 'bar'
fail unless 'bar' == Aw.fork! { 'bar' }

# It is expected to be nil
fail unless (Aw.fork! {}).nil?

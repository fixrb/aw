# frozen_string_literal: true

require "simplecov"

SimpleCov.command_name "Ruby tests"
SimpleCov.start

require_relative File.join("lib", "aw")

# It is expected to equal 42
raise unless 42.equal?(Aw.fork! { 6 * 7 })

# It is expected to eql 'bar'
raise unless "bar".eql?(Aw.fork! { "bar" })

# It is expected to be nil
# rubocop:disable Lint/EmptyBlock
raise unless (Aw.fork! {}).nil?
# rubocop:enable Lint/EmptyBlock

# It prevents from side effects
arr = ["foo"]
raise unless (Aw.fork! { arr << "FUU" }) == %w[foo FUU]
raise unless arr == ["foo"]

# It is expected to raise a generic error
begin
  Aw.fork! { raise "BOOM" }
rescue RuntimeError
  raise unless $ERROR_INFO.message == "BOOM"
end

# It is expected to initiate the termination of the script
begin
  Aw.fork! { exit(1) }
rescue SystemExit
  raise unless $ERROR_INFO.message == "exit"
end

# It is expected to return true
raise unless true.equal?(Aw.fork? { 6 * 7 })

# It is expected to return true
raise unless true.equal?(Aw.fork? { "bar" })

# It is expected to return true
# rubocop:disable Lint/EmptyBlock
raise unless true.equal?(Aw.fork? {})
# rubocop:enable Lint/EmptyBlock

# It is expected to prevent side effects and return true
arr = ["foo"]
raise unless true.equal?(Aw.fork? { arr << "FUU" })
raise unless arr == ["foo"]

# It is expected to return false
raise unless false.equal?(Aw.fork? { raise "BOOM" })

# It is expected to return false
raise unless false.equal?(Aw.fork? { exit(1) })

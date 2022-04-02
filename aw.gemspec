# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name         = "aw"
  spec.version      = File.read("VERSION.semver").chomp
  spec.author       = "Cyril Kato"
  spec.email        = "contact@cyril.email"
  spec.summary      = "Aw, fork 😬"
  spec.description  = "Creates a sub-process to execute a block inside, and returns what it returns (or a boolean)."
  spec.homepage     = "https://github.com/fixrb/aw"
  spec.license      = "MIT"
  spec.files        = Dir["LICENSE.md", "README.md", "lib/**/*"]

  spec.required_ruby_version = ">= 2.7.0"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rubocop-md"
  spec.add_development_dependency "rubocop-performance"
  spec.add_development_dependency "rubocop-rake"
  spec.add_development_dependency "rubocop-thread_safety"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "yard"

  spec.metadata["rubygems_mfa_required"] = "true"
end

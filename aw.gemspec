# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name                   = "aw"
  spec.version                = File.read("VERSION.semver").chomp
  spec.author                 = "Cyril Kato"
  spec.email                  = "contact@cyril.email"
  spec.summary                = "Aw, fork 😬"
  spec.description            = "Creates a sub-process to execute a block inside, and returns what it returns."
  spec.homepage               = "https://github.com/fixrb/aw"
  spec.license                = "MIT"
  spec.files                  = Dir["LICENSE.md", "README.md", "lib/**/*"]
  spec.required_ruby_version  = ">= 3.2.0"

  spec.metadata["rubygems_mfa_required"] = "true"
end

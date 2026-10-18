# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name                   = "aw"
  spec.version                = File.read(File.join(__dir__, "VERSION.semver")).chomp
  spec.author                 = "Cyril Kato"
  spec.email                  = "contact@cyril.email"
  spec.summary                = "Aw, fork 😬"
  spec.description            = "Runs a block in a forked child process and brings back what it returned, " \
                                "or re-raises what it raised. Side effects on the process stay in the child."
  spec.homepage               = "https://fixrb.dev/gems/aw/"
  spec.license                = "MIT"
  spec.files                  = Dir["LICENSE.md", "README.md", "lib/**/*.rb", base: __dir__]
  spec.required_ruby_version  = ">= 3.3.0"

  spec.metadata["bug_tracker_uri"]       = "https://github.com/fixrb/aw/issues"
  spec.metadata["documentation_uri"]     = "https://rubydoc.info/gems/aw"
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["source_code_uri"]       = "https://github.com/fixrb/aw"
end

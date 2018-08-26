# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'aw'
  spec.version       = File.read('VERSION.semver').chomp
  spec.authors       = ['Cyril Kato']
  spec.email         = ['contact@cyril.email']

  spec.summary       = 'Aw, fork!'
  spec.description   = 'Creates a subprocess to execute a block inside.'
  spec.homepage      = 'https://github.com/fixrb/aw'
  spec.license       = 'MIT'

  spec.files         =
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^test/}) }
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler',    '~> 1.16'
  spec.add_development_dependency 'rake',       '~> 12.3'
  spec.add_development_dependency 'rubocop',    '~> 0.58'
  spec.add_development_dependency 'simplecov',  '~> 0.16'
  spec.add_development_dependency 'yard',       '~> 0.9'

  spec.cert_chain   = ['certs/gem-fixrb-public_cert.pem']
  private_key       = File.expand_path('~/.ssh/gem-fixrb-private_key.pem')
  spec.signing_key  = private_key if File.exist?(private_key)
end

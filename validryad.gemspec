# frozen_string_literal: true

require_relative 'lib/validryad/version'

Gem::Specification.new do |spec|
  spec.name          = 'validryad'
  spec.version       = Validryad::VERSION
  spec.authors       = ['Nathan Armstrong']
  spec.email         = ['nathan@functionalflame.tech']

  spec.summary = 'A Ruby data validation tool, built to lean on dry-rb.'
  # spec.description   = 'TODO: Write a longer description or delete this line.'
  # spec.homepage      = "TODO: Put your gem's website or public repo URL here."
  spec.required_ruby_version = Gem::Requirement.new('>= 2.7.1')

  # spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"

  # spec.metadata['homepage_uri']    = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/armstnp/validryad'
  spec.metadata['changelog_uri']   = 'https://github.com/armstnp/validryad/blob/master/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'dry-monads', '~> 1.3', '>= 1.3.5'

  spec.add_development_dependency 'dry-types', '~> 1.4'
  spec.add_development_dependency 'rspec-parameterized', '~> 0.4.2'
end

# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'freeagent-cli'
  spec.version = '0.1'
  spec.authors = ['Simon Worthington']
  spec.email = ['simon@register-dynamics.co.uk']

  readme = File.read('README.txt').split("\n")
  spec.summary = readme.first
  spec.description = readme[1..].join("\n").strip
  spec.homepage = 'https://www.github.com/register-dynamics/freeagent-cli'
  spec.required_ruby_version = '>= 3.0.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.license = 'MIT'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\A#{spec.bindir}/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Uncomment to register a new dependency of your gem
  spec.add_dependency 'oauth2', '~> 2'
  spec.add_dependency 'webrick', '~> 1.9'
  spec.add_dependency 'thor', '~> 1.3'

  spec.add_development_dependency 'rake', '~> 13'

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end

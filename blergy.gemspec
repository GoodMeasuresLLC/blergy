# frozen_string_literal: true

require_relative "lib/blergy/version"

Gem::Specification.new do |spec|
  spec.name = "blergy"
  spec.version = Blergy::VERSION
  spec.authors = ["rob mathews"]
  spec.email = ["rob.mathews@goodmeasures.com"]

  spec.summary = "Create terraform configuration from an existing AWS Connect instance"
  spec.description =<<-DOC
  You've gone and created complicated Connect instance using the various GUI tools (or were gifted with
  the same by rando-contractors like LightStream). Now, you've boxed yourself in - you can't add new features
  or update APIs without testing in production.

  Despair no more - Blergy is for you. It examines the call flows, phone numbers, and creates:

  * exact variables for production
  * placeholder variables for staging and development
  * terraform templates that use those variables

  DOC
  spec.homepage = "https://github.com/GoodMeasuresLLC/blergy"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/GoodMeasuresLLC/blergy"
  spec.metadata["changelog_uri"] = "https://github.com/GoodMeasuresLLC/blergy/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "thor", "~> 1.0"
  spec.add_dependency 'aws-sdk'
  spec.add_dependency 'nokogiri'
  spec.add_development_dependency 'pry'
  # For more information and examples about making a new gem, checkout our
  # guide at: https://bundler.io/guides/creating_gem.html
end

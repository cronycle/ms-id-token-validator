lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "ms-id-token-validator/version"

Gem::Specification.new do |spec|
  spec.name = "ms-id-token-validator"
  spec.version = MsIdToken::Validator::VERSION
  spec.authors = ["QQ"]
  spec.email = ["me@quang.be"]

  spec.summary = "Validate the Microsoft Oauth2 ID token"
  spec.description = "Validate the id token from Microsoft oauth2 service"
  spec.homepage = "https://github.com/QQism/ms-id-token-validator"
  spec.license = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency("json-jwt", "~> 1.7")

  spec.add_development_dependency "bundler", "~> 2.2.33"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency("pry", "~> 0")
  spec.add_development_dependency("pry-doc", "~> 0")
  spec.add_development_dependency("timecop", "~> 0")
  spec.add_development_dependency("standard", "~> 0")
end

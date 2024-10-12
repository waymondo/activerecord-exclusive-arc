require_relative "lib/exclusive_arc/version"

Gem::Specification.new do |spec|
  spec.name = "activerecord-exclusive-arc"
  spec.version = ExclusiveArc::VERSION
  spec.authors = ["justin talbott"]
  spec.email = ["gmail@justintalbott.com"]

  spec.summary = "An ActiveRecord extension for polymorphic exclusive arc relationships"
  spec.homepage = "https://github.com/waymondo/exclusive-arc"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 6.1"
  spec.add_dependency "activesupport", ">= 6.1"
end

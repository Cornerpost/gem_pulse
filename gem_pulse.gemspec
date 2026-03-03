require_relative "lib/gem_pulse/version"

Gem::Specification.new do |spec|
  spec.name        = "gem_pulse"
  spec.version     = GemPulse::VERSION
  spec.authors     = [ "Cornerpost Digital LLC" ]
  spec.email       = [ "hello@cornerpostdigital.com" ]

  spec.homepage    = "https://github.com/cornerpost/gem_pulse"
  spec.summary     = "A mountable Rails engine providing an in-app gem health dashboard."
  spec.description = <<~DESC
    GemPulse is a mountable Rails engine that surfaces the health of your application's
    gem dependencies directly in your browser — no CLI required, no external SaaS needed.

    Mount it at /gem_pulse and get a live dashboard showing security advisories from the
    Ruby Advisory Database, version staleness, release cadence, license information, and
    an aggregate health score — sourced from the RubyGems.org API and bundler-audit.
  DESC

  spec.license = "MIT"

  spec.metadata["homepage_uri"]          = spec.homepage
  spec.metadata["source_code_uri"]       = "https://github.com/cornerpost/gem_pulse"
  spec.metadata["changelog_uri"]         = "https://github.com/cornerpost/gem_pulse/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"]       = "https://github.com/cornerpost/gem_pulse/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md", "CHANGELOG.md"]
  end

  spec.required_ruby_version = ">= 3.2.0"

  # Rails — the host framework
  spec.add_dependency "rails", ">= 8.1.2"

  # Security advisory data — Ruby Advisory Database via bundler-audit's Ruby API.
  # We call Bundler::Audit::Scanner directly; no shelling out required.
  spec.add_dependency "bundler-audit", ">= 0.9.0"

  # HTTP client for RubyGems.org API (version history, download counts, license, yanked status)
  spec.add_dependency "faraday",       ">= 2.0"
  spec.add_dependency "faraday-retry", ">= 2.0"
end

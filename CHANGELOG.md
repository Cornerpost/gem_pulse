# Changelog

All notable changes to GemPulse will be documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
GemPulse follows [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

### Planned
- Dashboard summary with aggregate health score
- Gem table with CVE status, staleness, and license per gem
- Per-gem detail page with full version history and advisory list
- Configurable `before_action` hook for host-app authentication
- RubyGems.org API integration with response caching
- bundler-audit Ruby API integration (no shell-out)

---

## [0.1.0] - 2026-03-03

### Added
- Initial engine scaffold (`rails plugin new gem_pulse --mountable`)
- `GemPulse::Configuration` class with `before_action`, `title`, and `cache_ttl` options
- `GemPulse.configure` block API
- Engine routes: `root`, `resources :gems`
- Production warning when mounted without access control
- MIT license, gemspec with `bundler-audit`, `faraday`, and `faraday-retry` dependencies

[Unreleased]: https://github.com/cornerpost/gem_pulse/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/cornerpost/gem_pulse/releases/tag/v0.1.0

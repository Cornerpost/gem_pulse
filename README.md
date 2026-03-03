# GemPulse

[![Gem Version](https://badge.fury.io/rb/gem_pulse.svg)](https://badge.fury.io/rb/gem_pulse)
[![CI](https://github.com/cornerpost/gem_pulse/actions/workflows/ci.yml/badge.svg)](https://github.com/cornerpost/gem_pulse/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

**A mountable Rails engine that puts your gem health dashboard inside your app.**

GemPulse surfaces the health of your application's gem dependencies directly in your browser — no CLI required, no external SaaS connection, no GitHub required. Mount it at `/gem_pulse`, point your team at the URL, and see the full health of your dependency graph at a glance.

---

## Why GemPulse?

Every Ruby security and dependency tool is CLI-only. `bundler-audit` finds CVEs. `libyear-bundler` measures staleness. But you have to run them yourself, read terminal output, and somehow share the results with your team.

GemPulse is the missing web UI layer. It uses `bundler-audit`'s Ruby API and the [RubyGems.org public API](https://guides.rubygems.org/rubygems-org-api/) to aggregate that data into a dashboard that lives inside your Rails app — visible to everyone with access to the admin section, no terminal needed.

The closest precedent, [gemsurance](https://github.com/appfolio/gemsurance), was archived in February 2023. GemPulse fills that gap.

---

## What It Shows

### Dashboard (`/gem_pulse`)
- **Health score** — aggregate score across all gems combining CVE status, staleness, and maintenance signals
- **Summary cards** — total gems, gems with CVEs, outdated count, unlicensed count
- **At-a-glance status** — are you in good shape or do you need to act?

### Gem Table (`/gem_pulse/gems`)
- Every gem in `Gemfile.lock` with its locked version and latest available version
- Per-gem health badge: 🟢 healthy · 🟡 outdated · 🔴 has CVEs
- Sortable by health score, staleness, or name
- Filter to show only gems with issues

### Gem Detail (`/gem_pulse/gems/:name`)
- Full version history from RubyGems.org
- All known security advisories for installed version (CVE ID, severity, description, patched versions)
- Release cadence — when the gem last published
- License
- Links to RubyGems.org, source repository, and bug tracker

---

## Installation

Add to your application's `Gemfile`:

```ruby
gem "gem_pulse"
```

Then run:

```bash
bundle install
```

---

## Mounting

Add to your `config/routes.rb`:

```ruby
mount GemPulse::Engine, at: "/gem_pulse"
```

That's it. Visit `http://localhost:3000/gem_pulse` to see your dashboard.

---

## Access Control

GemPulse has no built-in authentication — it delegates to whatever your app already uses. **Do not mount it publicly without protection.**

### With Devise (recommended)

```ruby
# config/routes.rb
authenticate :user, lambda { |u| u.admin? } do
  mount GemPulse::Engine, at: "/gem_pulse"
end
```

### With a before_action hook

```ruby
# config/initializers/gem_pulse.rb
GemPulse.configure do |config|
  config.before_action = -> { redirect_to root_path unless current_user&.admin? }
end
```

### With HTTP Basic Auth (for staging / demo environments)

```ruby
# config/routes.rb
constraints(->(req) {
  credentials = ActionController::HttpAuthentication::Basic.decode_credentials(req)
  credentials == "#{ENV['GEM_PULSE_USER']}:#{ENV['GEM_PULSE_PASSWORD']}"
}) do
  mount GemPulse::Engine, at: "/gem_pulse"
end
```

---

## Configuration

```ruby
# config/initializers/gem_pulse.rb
GemPulse.configure do |config|
  # Lambda or proc run as a before_action in GemPulse's controller.
  # Use this to enforce authentication when you can't use route constraints.
  # config.before_action = -> { redirect_to root_path unless current_user&.admin? }

  # Title shown in the dashboard navigation.
  # config.title = "Gem Health"

  # How long to cache RubyGems.org API responses, in seconds.
  # Prevents hammering the API on every page load.
  # config.cache_ttl = 3600  # default: 1 hour
end
```

---

## Data Sources

GemPulse combines three sources, all free and open:

| Source | What it provides | How it's used |
|--------|-----------------|---------------|
| `Gemfile.lock` | Locked gem versions | Parsed directly from the host app |
| [Ruby Advisory Database](https://github.com/rubysec/ruby-advisory-db) | CVE and GHSA advisories | Via `bundler-audit`'s Ruby API — no shelling out |
| [RubyGems.org API](https://guides.rubygems.org/rubygems-org-api/) | Latest versions, release dates, license, download counts | Faraday HTTP client with caching |

No data is sent anywhere. Everything runs locally inside your Rails process.

---

## Requirements

- Ruby >= 3.2
- Rails >= 8.1.2

---

## Contributing

Bug reports and pull requests are welcome at [github.com/cornerpost/gem_pulse](https://github.com/cornerpost/gem_pulse).

Before submitting a pull request, please:
1. Fork the repo and create a feature branch
2. Write tests for your change
3. Run `bin/rails test` in the `test/dummy` app and confirm they pass
4. Run `bin/rubocop` and resolve any offenses
5. Open a PR with a clear description of the problem and solution

For significant changes, open an issue first to discuss the approach.

---

## Roadmap

- [ ] Historical health snapshots — track your score over time
- [ ] Yanked gem detection — flag gems that have been yanked from RubyGems.org
- [ ] GitHub activity signals — last commit date, open issues, archived status
- [ ] Configurable alert thresholds — fail CI if health score drops below N
- [ ] Maintainer view — show gem owners how many apps run outdated versions

---

## License

GemPulse is available as open source under the [MIT License](https://opensource.org/licenses/MIT).

Copyright 2026 [Cornerpost Digital LLC](https://cornerpost.com).

---

## Acknowledgments

GemPulse builds on the excellent work of:
- [bundler-audit](https://github.com/rubysec/bundler-audit) and the [Ruby Advisory Database](https://github.com/rubysec/ruby-advisory-db) — security advisory data
- [RubyGems.org](https://rubygems.org) — version history, license, and download data
- [libyear-bundler](https://github.com/jaredbeck/libyear-bundler) — inspiration for the staleness metric

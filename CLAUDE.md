# GemPulse — CLAUDE.md

## What This Is

GemPulse is a mountable Rails engine that provides an in-app gem health dashboard. Mount it at `/gem_pulse` and get a browser-based view of every gem in the host app's `Gemfile.lock` — with security advisories, version staleness, and an aggregate health score.

**Primary purpose (v1):** Demo for the Ruby Central connection (Diesha). Mounted in ChessWire at `chesswire.org/gem_pulse`. The dashboard runs on real ChessWire gem data, making the pitch self-evident.

**Secondary purpose:** A genuinely useful open-source tool filling a real gap — no Rails-mountable gem health dashboard exists in the Ruby ecosystem. Gemsurance (the closest prior art) was archived in February 2023.

**Gem name:** `gem_pulse`
**Engine namespace:** `GemPulse`
**Mount point (conventional):** `/gem_pulse`
**License:** MIT
**Organization:** Cornerpost Digital LLC
**GitHub:** `github.com/cornerpost/gem_pulse`
**RubyGems.org:** (not yet published — publish after v0.1.0 is complete)

---

## Decisions Log

These are settled. Don't revisit them.

| Decision | Choice | Why |
|----------|--------|-----|
| Engine type | Mountable, isolated namespace | No bleed into host app. `isolate_namespace GemPulse` in engine.rb. |
| CSS | Self-contained, no framework | Works in any host app regardless of Tailwind/Bootstrap/nothing. Ships its own minimal stylesheet. |
| Database | Fully stateless — no migrations | Zero install friction. No `db:migrate` step. Reads `Gemfile.lock` + calls APIs on every page load. |
| Caching | `Rails.cache` from host app | Leverages whatever the host already has (memory, Solid Cache, Redis). Zero extra config. `cache_ttl` defaults to 1 hour. |
| Health score | Security-first | CVEs dominate the score. An unpatched CVE is more important than being 2 minor versions behind. |
| Data sources | RubyGems.org API + bundler-audit Ruby API | No shelling out. No external SaaS. No GitHub required. All free and open. |
| HTTP client | Faraday + faraday-retry | Consistent with ChessWire. Resilient to transient API failures. |
| Testing | Unit (mocked) + integration (dummy app) | Data layer tested with fixture/mocked responses. Controllers/views tested through the Rails dummy app. |
| v0.1.0 scope | Dashboard + gem table + per-gem detail | Three-page flow. Full enough to be a credible demo. |
| v2 database | Not decided | Stateless v1 ships. Don't make any design decisions that foreclose either option (host DB vs separate SQLite). |
| JS | Minimal — plain ERB, no Stimulus yet | Sorting/filtering via standard Rails forms and query params. Add Stimulus in v2 if needed. |
| Target user (v1) | Technical — developer literacy assumed | Dense information is fine. Show CVE IDs, version numbers, libyear values directly. No need to explain what a gem is. |

---

## Tech Stack

| Layer | Choice |
|-------|--------|
| Framework | Rails engine (`rails plugin new gem_pulse --mountable`) |
| Ruby | >= 3.2 |
| Rails | >= 8.1.2 |
| Security data | `bundler-audit` >= 0.9 (Ruby API, no shell-out) |
| HTTP client | `faraday` >= 2.0 + `faraday-retry` >= 2.0 |
| CSS | Self-contained (`app/assets/stylesheets/gem_pulse/`) |
| JS | None in v1 |
| Testing | Rails default (Minitest), WebMock for HTTP mocking |
| Dummy app | `test/dummy/` — a full Rails app that mounts the engine for integration tests |

---

## Project Structure

```
gem_pulse/
├── app/
│   ├── assets/
│   │   └── stylesheets/
│   │       └── gem_pulse/
│   │           └── application.css     # Self-contained styles. No Tailwind/Bootstrap.
│   ├── controllers/
│   │   └── gem_pulse/
│   │       ├── application_controller.rb  # before_action hook, gem_pulse_config helper
│   │       ├── dashboard_controller.rb    # GET / — summary dashboard
│   │       └── gems_controller.rb         # GET /gems, GET /gems/:name
│   ├── models/
│   │   └── gem_pulse/
│   │       ├── gem_inspector.rb      # Parses Gemfile + Gemfile.lock from host app
│   │       ├── advisory_scanner.rb   # Wraps Bundler::Audit::Scanner Ruby API
│   │       ├── rubygems_client.rb    # Calls RubyGems.org API v2, uses Rails.cache
│   │       └── health_score.rb       # Combines sources into 0–100 score
│   └── views/
│       ├── layouts/
│       │   └── gem_pulse/
│       │       └── application.html.erb  # Engine layout, self-contained
│       └── gem_pulse/
│           ├── dashboard/
│           │   └── index.html.erb    # Summary cards + top issues
│           └── gems/
│               ├── index.html.erb    # Full gem table, sortable
│               └── show.html.erb     # Per-gem detail: advisories, version history
├── config/
│   └── routes.rb                     # root dashboard#index, resources :gems
├── lib/
│   ├── gem_pulse.rb                  # GemPulse module + Configuration class
│   ├── gem_pulse/
│   │   ├── engine.rb                 # Engine class, initializers
│   │   └── version.rb                # GemPulse::VERSION
│   └── tasks/
│       └── gem_pulse_tasks.rake      # (empty for now)
├── test/
│   ├── dummy/                        # Full Rails app for integration tests
│   │   └── config/routes.rb          # Mounts GemPulse::Engine at /gem_pulse
│   ├── models/
│   │   └── gem_pulse/
│   │       ├── gem_inspector_test.rb
│   │       ├── advisory_scanner_test.rb
│   │       ├── rubygems_client_test.rb
│   │       └── health_score_test.rb
│   └── integration/
│       ├── dashboard_test.rb
│       └── gems_test.rb
├── gem_pulse.gemspec
├── CHANGELOG.md
├── MIT-LICENSE
└── README.md
```

---

## Data Layer

Four plain Ruby classes. No ActiveRecord. No database. All live in `app/models/gem_pulse/`.

### `GemPulse::GemInspector`

Parses the host app's `Gemfile` and `Gemfile.lock`. Returns a list of gem records.

```ruby
inspector = GemPulse::GemInspector.new(app_root: Rails.root)
inspector.gems
# => [
#   { name: "rails",    locked_version: "8.1.2", declared_version: ">= 8.1.2", groups: [:default] },
#   { name: "nokogiri", locked_version: "1.16.4", declared_version: ">= 0",     groups: [:default] },
#   ...
# ]
```

Key details:
- Reads `Gemfile.lock` using `Bundler::LockfileParser` (bundler is always available in a Rails app — don't re-implement the parser)
- Reads `Gemfile` using `Bundler::Dsl` to get declared version constraints and groups
- Skips development/test group gems by default (configurable)
- Returns path gems and git gems with a `source: :path` or `source: :git` flag — don't hit the RubyGems.org API for these

### `GemPulse::AdvisoryScanner`

Wraps `Bundler::Audit::Scanner` from the `bundler-audit` gem. Returns per-gem advisory data.

```ruby
scanner = GemPulse::AdvisoryScanner.new(app_root: Rails.root)
scanner.advisories
# => {
#   "nokogiri" => [
#     {
#       gem:             "nokogiri",
#       cve:             "CVE-2024-1234",
#       ghsa:            "GHSA-xxxx-xxxx-xxxx",
#       url:             "https://github.com/advisories/GHSA-xxxx-xxxx-xxxx",
#       title:           "...",
#       description:     "...",
#       cvss_v3:         8.1,
#       severity:        "high",    # critical / high / medium / low / unknown
#       patched_versions: [">= 1.16.5"],
#       unaffected_versions: []
#     }
#   ]
# }
```

Key details:
- Use `Bundler::Audit::Scanner` Ruby API directly — **never shell out to `bundle-audit`**
- `Bundler::Audit::Database.update!` is slow and hits the network. Don't call it on every request. Call it in a background job or at boot. For v1, use the bundled advisory DB that ships with the gem.
- Returns a Hash keyed by gem name for O(1) lookup in `HealthScore`

### `GemPulse::RubygemsClient`

Calls the RubyGems.org API v2. Caches responses using `Rails.cache`.

```ruby
client = GemPulse::RubygemsClient.new
client.info("rails")
# => {
#   name:           "rails",
#   latest_version: "8.1.2",
#   versions:       [{ number: "8.1.2", created_at: "2025-01-01", downloads: 12345 }, ...],
#   licenses:       ["MIT"],
#   homepage_uri:   "https://rubyonrails.org",
#   source_code_uri: "https://github.com/rails/rails",
#   yanked:         false
# }
```

Key details:
- **API endpoint:** `GET https://rubygems.org/api/v2/rubygems/{name}/versions/{version}.json`
- **For version list:** `GET https://rubygems.org/api/v1/versions/{name}.json`
- **Cache key:** `"gem_pulse/rubygems/#{gem_name}"`, TTL from `GemPulse.configuration.cache_ttl` (default 1 hour)
- Path gems (`source: :path`) and git gems — return `nil` immediately without an API call
- On API error (404, timeout, rate limit): return `nil` and let `HealthScore` handle it gracefully with an `"unknown"` status
- Faraday connection should set a 5-second open timeout and 10-second read timeout

### `GemPulse::HealthScore`

Combines data from all three sources into a 0–100 score and a status string.

```ruby
score = GemPulse::HealthScore.new(
  gem_name:    "nokogiri",
  locked_version: "1.16.4",
  rubygems_data:  client.info("nokogiri"),
  advisories:     scanner.advisories["nokogiri"] || []
)

score.value   # => 42
score.status  # => "critical"   # critical / warning / healthy / unknown
score.reasons # => ["1 high CVE (CVE-2024-1234)", "3 versions behind latest (1.16.7)"]
```

**Scoring algorithm (security-first):**

Start at 100. Apply penalties in order:

1. **Critical CVE (CVSS >= 9.0):** score = 0 immediately. Stop.
2. **High CVE (CVSS >= 7.0):** subtract 50 per CVE, floor at 5.
3. **Medium CVE (CVSS >= 4.0):** subtract 25 per CVE.
4. **Low CVE (CVSS < 4.0 or unknown severity):** subtract 10 per CVE.
5. **Major versions behind:** subtract 15 per major version.
6. **Minor versions behind:** subtract 3 per minor version (max 15).
7. **Days since last release:**
   - < 180 days: no penalty
   - 180–365 days: subtract 5
   - 1–2 years: subtract 10
   - > 2 years: subtract 20
8. **Yanked version:** score = 0.
9. **API data unavailable (path gem, git gem, or API error):** status = `"unknown"`, no score displayed.

**Status thresholds:**
- `"healthy"`: score >= 80
- `"warning"`: score 50–79
- `"critical"`: score < 50
- `"unknown"`: no API data available

---

## Routes

```ruby
# config/routes.rb
GemPulse::Engine.routes.draw do
  root to: "dashboard#index"

  # /gem_pulse/gems        → GemsController#index  (full sortable gem table)
  # /gem_pulse/gems/rails  → GemsController#show   (per-gem detail)
  resources :gems, only: [ :index, :show ], param: :name
end
```

When mounted in ChessWire at `/gem_pulse`:
- `/gem_pulse`             → dashboard summary
- `/gem_pulse/gems`        → full gem table
- `/gem_pulse/gems/rails`  → Rails gem detail page

---

## Controllers

### `GemPulse::ApplicationController`

Base controller for all GemPulse controllers. Handles the authentication hook.

```ruby
module GemPulse
  class ApplicationController < ActionController::Base
    before_action :run_gem_pulse_before_action
    helper_method :gem_pulse_config

    private

    def run_gem_pulse_before_action
      hook = GemPulse.configuration.before_action
      instance_exec(&hook) if hook
    end

    def gem_pulse_config
      GemPulse.configuration
    end
  end
end
```

### `GemPulse::DashboardController`

Loads all gem data, computes scores, and renders the summary view.

```ruby
module GemPulse
  class DashboardController < ApplicationController
    def index
      @gems = load_gem_health   # returns Array of { name:, score:, status:, reasons: }
      @summary = compute_summary(@gems)
    end
  end
end
```

### `GemPulse::GemsController`

```ruby
module GemPulse
  class GemsController < ApplicationController
    def index
      @gems  = load_gem_health
      @gems  = sort_gems(@gems, params[:sort], params[:direction])
      @gems  = filter_gems(@gems, params[:status])
    end

    def show
      @gem_name = params[:name]
      # Load full detail: all versions, all advisories, score breakdown
    end
  end
end
```

Sorting and filtering use query params — no JavaScript required:
- `?sort=score&direction=asc`
- `?sort=name`
- `?status=critical` (filter to gems with `status == "critical"`)

---

## Views

Three views + one layout. Self-contained — no partials from the host app.

### Layout (`app/views/layouts/gem_pulse/application.html.erb`)

- Uses `gem_pulse_config.title` for the page title
- Includes `gem_pulse/application` stylesheet
- Nav: title link → root, "Gems" link → gems index
- Flash message block

### Dashboard (`app/views/gem_pulse/dashboard/index.html.erb`)

Four summary cards:
1. **Total gems** — count from Gemfile.lock
2. **With CVEs** — count of gems with any advisory
3. **Outdated** — count with score < 80
4. **Aggregate score** — average score across all gems (or weighted)

Below cards: a condensed table of the worst-scoring gems (bottom 10 by score). Each row links to the gem detail page.

### Gem Table (`app/views/gem_pulse/gems/index.html.erb`)

Full table, one row per gem:

| Gem | Locked | Latest | Status | Score | Last Release |
|-----|--------|--------|--------|-------|--------------|
| nokogiri | 1.16.4 | 1.16.7 | 🔴 Critical | 42 | 3 days ago |

Column headers are links that toggle sort order via query params.
Status filter links above the table: All · Critical · Warning · Healthy · Unknown.

### Gem Detail (`app/views/gem_pulse/gems/show.html.erb`)

- Header: gem name, locked version, latest version, status badge, score
- Score breakdown: bullet list of reasons (from `score.reasons`)
- **Advisories section:** table of CVEs — ID, severity, title, affected versions, patched versions, link to advisory
- **Version history:** last 10 releases from RubyGems.org — version number, release date, download count
- Links: RubyGems.org page, homepage, source code, bug tracker

---

## CSS

Self-contained in `app/assets/stylesheets/gem_pulse/application.css`. No Tailwind, no Bootstrap, no external fonts.

Design goals:
- Readable without being pretty. Dense information laid out clearly.
- Status colors must be clear: green (healthy), yellow (warning), red (critical), grey (unknown).
- Works on both light and dark host app backgrounds — use a lightly bordered card layout so the GemPulse panel is visually distinct from whatever surrounds it.
- Mobile-readable (single column) but desktop-first (table layout).

Status badge colors (CSS custom properties for easy theming):
```css
--gem-pulse-healthy:  #22c55e;   /* green */
--gem-pulse-warning:  #f59e0b;   /* amber */
--gem-pulse-critical: #ef4444;   /* red */
--gem-pulse-unknown:  #9ca3af;   /* grey */
```

---

## Configuration

```ruby
# GemPulse::Configuration (lib/gem_pulse.rb)
#
# Host apps configure in config/initializers/gem_pulse.rb:
#
#   GemPulse.configure do |config|
#     config.before_action = -> { redirect_to root_path unless current_user&.admin? }
#     config.title         = "Gem Health"
#     config.cache_ttl     = 3600
#   end

class Configuration
  attr_accessor :before_action   # Proc/lambda — run as before_action in ApplicationController
  attr_accessor :title           # String — dashboard title shown in nav
  attr_accessor :cache_ttl       # Integer — seconds to cache RubyGems.org responses (default: 3600)

  def initialize
    @before_action = nil
    @title         = "Gem Health"
    @cache_ttl     = 3600
  end
end
```

**Access control patterns for host apps:**

```ruby
# Option 1: Route constraint with Devise
authenticate :user, lambda { |u| u.admin? } do
  mount GemPulse::Engine, at: "/gem_pulse"
end

# Option 2: before_action hook (no Devise)
GemPulse.configure do |config|
  config.before_action = -> { redirect_to root_path unless current_user&.admin? }
end

# Option 3: HTTP Basic Auth (for staging/demo)
constraints(->(req) {
  credentials = ActionController::HttpAuthentication::Basic.decode_credentials(req)
  credentials == "#{ENV['GEM_PULSE_USER']}:#{ENV['GEM_PULSE_PASSWORD']}"
}) do
  mount GemPulse::Engine, at: "/gem_pulse"
end
```

---

## Caching Strategy

All RubyGems.org API calls go through `Rails.cache`:

```ruby
def info(gem_name)
  Rails.cache.fetch("gem_pulse/rubygems/#{gem_name}", expires_in: GemPulse.configuration.cache_ttl) do
    fetch_from_api(gem_name)
  end
end
```

On a dashboard page load hitting 50 gems:
- First load: 50 API calls, results cached for 1 hour
- Subsequent loads within the hour: 0 API calls, served from cache
- After TTL expires: the next request refreshes the cache

The host app's cache backend handles this transparently — Solid Cache in ChessWire's case.

**Important:** Never call `Bundler::Audit::Database.update!` on a web request. The advisory database ships with the `bundler-audit` gem and is current enough for v1. If keeping the advisory DB current matters, call it in a background job outside the request cycle.

---

## Testing

### Unit Tests — Data Layer (`test/models/gem_pulse/`)

Test each class in isolation with mocked/fixture data.

**`GemInspectorTest`** — parse real fixture Gemfile.lock files. Test that:
- Gems are returned with correct name and locked version
- Path gems are flagged correctly
- Git gems are flagged correctly

**`AdvisoryScannerTest`** — use a fixture Gemfile.lock that contains known vulnerable versions. Test that:
- Advisories are returned for vulnerable gems
- Output is keyed by gem name
- Gems with no advisories return an empty array, not nil

**`RubygemsClientTest`** — stub HTTP with WebMock. Test that:
- A successful response is parsed correctly
- A 404 returns nil gracefully
- A timeout returns nil gracefully
- Responses are read from cache on second call (assert HTTP call made only once)

**`HealthScoreTest`** — pure unit tests, no HTTP. Test that:
- A gem with a critical CVE scores 0
- A gem with no issues scores 100
- Staleness penalties apply correctly
- Yanked gems score 0
- Unknown (path gem) returns status "unknown"

### Integration Tests — Controllers/Views (`test/integration/`)

Test the full request/response cycle through the mounted dummy app.

**`DashboardTest`:**
- `GET /gem_pulse` returns 200
- Response contains the summary card structure
- Works with an empty Gemfile.lock (edge case)

**`GemsTest`:**
- `GET /gem_pulse/gems` returns 200, contains gem names
- `GET /gem_pulse/gems/rails` returns 200 for a gem that exists
- `GET /gem_pulse/gems/nonexistent` returns 404
- Sort params change the order of results
- Status filter params filter correctly

### Running Tests

```bash
# From gem_pulse root:
bin/rails test                     # all tests
bin/rails test test/models         # unit tests only
bin/rails test test/integration    # integration tests only
bin/rubocop                        # lint
```

The dummy app at `test/dummy/` is a full Rails app with GemPulse mounted. Its `Gemfile.lock` is used as the test fixture for integration tests. Keep it realistic — don't artificially clean it up.

---

## Development Workflow

### Running the dummy app

```bash
cd gem_pulse
bundle install
bin/rails server   # starts test/dummy app at localhost:3000
open http://localhost:3000/gem_pulse
```

The dummy app's `Gemfile.lock` is what GemPulse will display. As you add gems to the dummy app, they'll show up in the dashboard.

### Testing in ChessWire (host app)

```ruby
# In ChessWire's Gemfile:
gem "gem_pulse", path: "../gem_pulse"

# In ChessWire's config/routes.rb:
mount GemPulse::Engine, at: "/gem_pulse"
```

Changes to `gem_pulse/` are reflected in ChessWire immediately (no re-bundling needed for code changes, only for gemspec changes).

---

## Release Process

GemPulse uses standard RubyGems release tooling.

**To publish a new version:**

1. Update `lib/gem_pulse/version.rb` — bump `VERSION`
2. Update `CHANGELOG.md` — move `[Unreleased]` to the new version with date
3. Commit: `git commit -m "Release v0.X.Y"`
4. Tag: `git tag v0.X.Y`
5. Push: `git push && git push --tags`
6. Release: `bundle exec rake release` — builds the `.gem` file and pushes to RubyGems.org

**First-time RubyGems.org setup:**
```bash
gem signin   # or set RUBYGEMS_API_KEY env var
```

MFA is required (`rubygems_mfa_required: true` is set in gemspec).

---

## Data Sources

| Source | What it provides | API / access method |
|--------|-----------------|---------------------|
| Host app's `Gemfile.lock` | Locked gem versions | `Bundler::LockfileParser` |
| Host app's `Gemfile` | Declared constraints, groups | `Bundler::Dsl` |
| Ruby Advisory Database | CVEs and GHSA advisories | `Bundler::Audit::Scanner` Ruby API (ships with `bundler-audit` gem) |
| RubyGems.org API v1 | Version list with release dates | `GET /api/v1/versions/{name}.json` |
| RubyGems.org API v2 | Version detail, yanked status, license | `GET /api/v2/rubygems/{name}/versions/{version}.json` |

No GitHub API in v1. No external SaaS. No data sent anywhere — all processing happens locally inside the host Rails process.

---

## v0.1.0 Scope

**Included:**
- Dashboard summary (total gems, CVE count, outdated count, aggregate score)
- Gem table with sort and status filter
- Gem detail page (advisories, version history, score breakdown)
- `before_action` authentication hook
- `Rails.cache` caching for RubyGems.org API responses
- Self-contained CSS with status color system
- Production warning when mounted without access control
- Unit tests for all four data layer classes
- Integration tests for dashboard and gems controller

**Explicitly deferred to v0.2.0+:**
- Historical health snapshots and trend charts
- Yanked gem detection (RubyGems.org v2 `yanked` field)
- GitHub API integration (repo activity, archived status)
- Configurable health score weights
- Stimulus controllers for client-side filtering
- CI integration / rake task for threshold enforcement
- Maintainer view (how many apps run your gem outdated)

---

## What This Project Is Not

- Not a replacement for `bundle update` — GemPulse is read-only. It shows you what needs attention; it doesn't act.
- Not a CI tool (yet) — the dashboard is for humans, not pipelines. CI integration comes in v2.
- Not an external service — no SaaS, no data egress, no API keys required (beyond RubyGems.org's public API).
- Not a security scanner for your own code — that's `brakeman`'s job. GemPulse scans your *dependencies*, not your application code.

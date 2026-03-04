module GemPulse
  class GemCategorizer
    CATEGORIES = {
      "Web Framework"   => %w[rails railties actionpack actionview actioncable actionmailbox actionmailer actiontext sinatra roda hanami],
      "ORM / Database"  => %w[activerecord sqlite3 pg mysql2 trilogy sequel rom-rb rom-sql activemodel],
      "Web Server"      => %w[puma unicorn thin falcon thruster rackup nio4r],
      "HTTP Client"     => %w[faraday faraday-retry faraday-multipart httparty rest-client typhoeus excon net-http-persistent],
      "Asset Pipeline"  => %w[propshaft sprockets tailwindcss-rails tailwindcss-ruby dartsass-rails cssbundling-rails jsbundling-rails],
      "JavaScript"      => %w[turbo-rails stimulus-rails importmap-rails],
      "Background Jobs" => %w[solid_queue solid_cable sidekiq good_job delayed_job resque activejob],
      "Caching"         => %w[solid_cache dalli redis hiredis connection_pool],
      "Authentication"  => %w[devise omniauth bcrypt doorkeeper rodauth warden],
      "Authorization"   => %w[pundit cancancan action_policy],
      "API / Serialization" => %w[jbuilder oj multi_json alba blueprinter grape jsonapi-serializer json json-schema],
      "File Storage"    => %w[activestorage aws-sdk-s3 image_processing mini_magick ruby-vips shrine carrierwave marcel mini_mime],
      "Content"         => %w[friendly_id pagy kaminari will_paginate ransack pg_search],
      "Security"        => %w[bundler-audit brakeman rack-attack bcrypt_pbkdf ed25519 securerandom],
      "Email"           => %w[letter_opener mailcatcher premailer mail net-imap net-pop net-smtp],
      "Testing"         => %w[minitest rspec capybara selenium-webdriver webmock vcr factory_bot faker mocha shoulda-matchers simplecov xpath rubyzip],
      "Debugging"       => %w[debug byebug pry web-console better_errors binding_of_caller bindex irb reline],
      "Code Quality"    => %w[rubocop rubocop-rails rubocop-rails-omakase rubocop-performance rubocop-minitest rubocop-rspec standard lint_roller],
      "Deployment"      => %w[kamal capistrano mina sshkit net-ssh net-scp net-sftp dotenv],
      "Monitoring"      => %w[sentry-ruby sentry-rails newrelic_rpm datadog scout_apm skylight],
      "XML / HTML"      => %w[nokogiri loofah rails-html-sanitizer rails-dom-testing rexml builder erubi erb crass],
      "Middleware"      => %w[rack rack-session rack-test rack-cors rack-proxy],
      "Core / Runtime"  => %w[bootsnap concurrent-ruby tzinfo zeitwerk i18n globalid thor rake msgpack ffi],
      "Net / Protocol"  => %w[net-http net-protocol addressable public_suffix uri websocket websocket-driver websocket-extensions useragent],
      "Parsing"         => %w[racc psych prism parser ast bigdecimal date stringio timeout tsort pp prettyprint ostruct io-console rdoc yaml drb base64],
      "Scheduling"      => %w[fugit et-orbi raabro],
      "I18n / Unicode"  => %w[unicode-display_width unicode-emoji rainbow],
    }.freeze

    # Flat lookup: gem_name => category
    LOOKUP = CATEGORIES.each_with_object({}) do |(category, gems), hash|
      gems.each { |gem_name| hash[gem_name] = category }
    end.freeze

    def initialize(gem_names: [], groups: {})
      @gem_names = gem_names
      @groups = groups  # { gem_name => [:default, :development, ...] }
    end

    # Returns the category for a single gem
    def categorize(gem_name)
      # 1. Check curated lookup
      return LOOKUP[gem_name] if LOOKUP.key?(gem_name)

      # 2. Check Bundler groups for hints
      gem_groups = @groups[gem_name] || []
      return "Testing" if (gem_groups & [:test]).any?
      return "Development" if (gem_groups & [:development]).any? && (gem_groups & [:default]).none?

      # 3. Name-based heuristics
      return "Rails Internals" if gem_name.start_with?("action", "active")
      return "Rack Middleware" if gem_name.start_with?("rack-")
      return "Faraday Plugin" if gem_name.start_with?("faraday-")
      return "Code Quality" if gem_name.start_with?("rubocop")
      return "Net / Protocol" if gem_name.start_with?("net-")
      return "Deployment" if gem_name.start_with?("sshkit", "net-ssh", "net-scp")

      "Other"
    end

    # Returns a hash of category => [gem_names], sorted by category name
    def grouped
      result = Hash.new { |h, k| h[k] = [] }
      @gem_names.each { |name| result[categorize(name)] << name }
      result.sort_by(&:first).to_h
    end

    # Returns summary: category => count, sorted by count desc
    def summary
      grouped.transform_values(&:size).sort_by { |_, v| -v }.to_h
    end

    # All known categories (including ones with 0 gems)
    def self.all_categories
      CATEGORIES.keys
    end
  end
end

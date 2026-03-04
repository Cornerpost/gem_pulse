require "faraday"
require "faraday/retry"

module GemPulse
  class RubygemsClient
    BASE_URL = "https://rubygems.org"

    def info(gem_name)
      Rails.cache.fetch(cache_key(gem_name), expires_in: cache_ttl, skip_nil: true) do
        fetch_gem_info(gem_name)
      end
    end

    private

    def fetch_gem_info(gem_name)
      version_detail = fetch_version_detail(gem_name)
      return nil unless version_detail

      versions = fetch_versions(gem_name) || []

      {
        name: gem_name,
        latest_version: version_detail["version"],
        versions: versions.map { |v| normalize_version(v) },
        licenses: version_detail["licenses"] || [],
        homepage_uri: version_detail["homepage_uri"],
        source_code_uri: version_detail["source_code_uri"],
        bug_tracker_uri: version_detail["bug_tracker_uri"],
        yanked: version_detail["yanked"] == true
      }
    rescue Faraday::Error
      nil
    end

    def fetch_version_detail(gem_name)
      response = connection.get("/api/v2/rubygems/#{gem_name}/versions/latest.json")
      return nil unless response.status == 200
      JSON.parse(response.body)
    rescue Faraday::Error, JSON::ParserError
      nil
    end

    def fetch_versions(gem_name)
      response = connection.get("/api/v1/versions/#{gem_name}.json")
      return nil unless response.status == 200
      JSON.parse(response.body)
    rescue Faraday::Error, JSON::ParserError
      nil
    end

    def normalize_version(v)
      {
        number: v["number"],
        created_at: v["created_at"],
        downloads: v["downloads_count"] || v["downloads"]
      }
    end

    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |f|
        f.request :retry, max: 2, interval: 0.5, backoff_factor: 2
        f.options.open_timeout = 5
        f.options.timeout = 10
        f.adapter Faraday.default_adapter
      end
    end

    def cache_key(gem_name)
      "gem_pulse/rubygems/#{gem_name}"
    end

    def cache_ttl
      GemPulse.configuration.cache_ttl
    end
  end
end

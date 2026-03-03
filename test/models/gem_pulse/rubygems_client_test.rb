require "test_helper"
require "webmock/minitest"

module GemPulse
  class RubygemsClientTest < ActiveSupport::TestCase
    setup do
      @client = RubygemsClient.new

      @version_detail_response = {
        "name" => "rails",
        "version" => "8.1.2",
        "licenses" => ["MIT"],
        "homepage_uri" => "https://rubyonrails.org",
        "source_code_uri" => "https://github.com/rails/rails",
        "bug_tracker_uri" => "https://github.com/rails/rails/issues",
        "yanked" => false
      }.to_json

      @versions_response = [
        { "number" => "8.1.2", "created_at" => "2025-06-01T00:00:00Z", "downloads_count" => 50000 },
        { "number" => "8.1.1", "created_at" => "2025-05-01T00:00:00Z", "downloads_count" => 100000 },
        { "number" => "8.0.0", "created_at" => "2025-01-01T00:00:00Z", "downloads_count" => 200000 }
      ].to_json
    end

    test "successful response returns parsed gem info" do
      stub_rubygems_api("rails")

      result = @client.info("rails")

      assert_equal "rails", result[:name]
      assert_equal "8.1.2", result[:latest_version]
      assert_equal ["MIT"], result[:licenses]
      assert_equal "https://rubyonrails.org", result[:homepage_uri]
      assert_equal false, result[:yanked]
      assert_equal 3, result[:versions].size
      assert_equal "8.1.2", result[:versions].first[:number]
    end

    test "404 returns nil" do
      stub_request(:get, "https://rubygems.org/api/v2/rubygems/nonexistent/versions/latest.json")
        .to_return(status: 404, body: "Not Found")

      assert_nil @client.info("nonexistent")
    end

    test "timeout returns nil" do
      stub_request(:get, "https://rubygems.org/api/v2/rubygems/timeout_gem/versions/latest.json")
        .to_timeout

      assert_nil @client.info("timeout_gem")
    end

    test "responses are cached on second call" do
      original_cache = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new

      detail_stub = stub_request(:get, "https://rubygems.org/api/v2/rubygems/rails/versions/latest.json")
        .to_return(status: 200, body: @version_detail_response, headers: { "Content-Type" => "application/json" })
      versions_stub = stub_request(:get, "https://rubygems.org/api/v1/versions/rails.json")
        .to_return(status: 200, body: @versions_response, headers: { "Content-Type" => "application/json" })

      @client.info("rails")
      @client.info("rails")

      assert_requested detail_stub, times: 1
      assert_requested versions_stub, times: 1
    ensure
      Rails.cache = original_cache
    end

    test "versions are normalized with number, created_at, and downloads" do
      stub_rubygems_api("rails")

      result = @client.info("rails")
      version = result[:versions].first

      assert_equal "8.1.2", version[:number]
      assert_equal "2025-06-01T00:00:00Z", version[:created_at]
      assert_equal 50000, version[:downloads]
    end

    private

    def stub_rubygems_api(gem_name)
      stub_request(:get, "https://rubygems.org/api/v2/rubygems/#{gem_name}/versions/latest.json")
        .to_return(status: 200, body: @version_detail_response, headers: { "Content-Type" => "application/json" })
      stub_request(:get, "https://rubygems.org/api/v1/versions/#{gem_name}.json")
        .to_return(status: 200, body: @versions_response, headers: { "Content-Type" => "application/json" })
    end
  end
end

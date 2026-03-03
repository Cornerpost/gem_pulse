require "test_helper"

module GemPulse
  class AdvisoryScannerTest < ActiveSupport::TestCase
    setup do
      @fixture_root = File.expand_path("../../fixtures/files", __dir__)
    end

    test "returns hash keyed by gem name" do
      scanner = AdvisoryScanner.new(app_root: @fixture_root)
      result = scanner.advisories
      assert_kind_of Hash, result
    end

    test "advisory values are arrays of hashes" do
      scanner = AdvisoryScanner.new(app_root: @fixture_root)
      result = scanner.advisories
      result.each_value do |advs|
        assert_kind_of Array, advs
        assert advs.all? { |a| a.is_a?(Hash) }
      end
    end

    test "advisory entries have expected keys" do
      scanner = AdvisoryScanner.new(app_root: @fixture_root)
      result = scanner.advisories
      result.each_value do |advs|
        advs.each do |adv|
          assert adv.key?(:cve) || adv.key?(:ghsa), "Advisory should have :cve or :ghsa key"
          assert adv.key?(:title), "Advisory should have :title key"
          assert adv.key?(:severity), "Advisory should have :severity key"
          assert adv.key?(:cvss_v3), "Advisory should have :cvss_v3 key"
          assert adv.key?(:patched_versions), "Advisory should have :patched_versions key"
        end
      end
    end

    test "severity is a valid value" do
      scanner = AdvisoryScanner.new(app_root: @fixture_root)
      result = scanner.advisories
      valid_severities = %w[critical high medium low unknown]
      result.each_value do |advs|
        advs.each do |adv|
          assert_includes valid_severities, adv[:severity]
        end
      end
    end

    test "patched_versions is an array of strings" do
      scanner = AdvisoryScanner.new(app_root: @fixture_root)
      result = scanner.advisories
      result.each_value do |advs|
        advs.each do |adv|
          assert_kind_of Array, adv[:patched_versions]
          adv[:patched_versions].each { |v| assert_kind_of String, v }
        end
      end
    end
  end
end

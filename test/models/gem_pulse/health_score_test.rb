require "test_helper"

module GemPulse
  class HealthScoreTest < ActiveSupport::TestCase
    test "gem with no issues scores 100" do
      score = build_score(advisories: [], latest_version: "1.0.0", locked_version: "1.0.0")
      assert_equal 100, score.value
      assert_equal "healthy", score.status
    end

    test "critical CVE sets score to 0" do
      advisories = [{ cve: "CVE-2024-0001", cvss_v3: 9.5, title: "Critical vuln" }]
      score = build_score(advisories: advisories)
      assert_equal 0, score.value
      assert_equal "critical", score.status
    end

    test "high CVE subtracts 50 per CVE with floor at 5" do
      advisories = [{ cve: "CVE-2024-0002", cvss_v3: 7.5, title: "High vuln" }]
      score = build_score(advisories: advisories)
      assert_equal 50, score.value
      assert_equal "warning", score.status
    end

    test "two high CVEs floor at 5" do
      advisories = [
        { cve: "CVE-2024-0002", cvss_v3: 7.5, title: "High vuln 1" },
        { cve: "CVE-2024-0003", cvss_v3: 8.0, title: "High vuln 2" }
      ]
      score = build_score(advisories: advisories)
      assert_equal 5, score.value
      assert_equal "critical", score.status
    end

    test "medium CVE subtracts 25" do
      advisories = [{ cve: "CVE-2024-0004", cvss_v3: 5.0, title: "Medium vuln" }]
      score = build_score(advisories: advisories)
      assert_equal 75, score.value
      assert_equal "warning", score.status
    end

    test "low CVE subtracts 10" do
      advisories = [{ cve: "CVE-2024-0005", cvss_v3: 2.0, title: "Low vuln" }]
      score = build_score(advisories: advisories)
      assert_equal 90, score.value
      assert_equal "healthy", score.status
    end

    test "major versions behind subtract 15 each" do
      score = build_score(locked_version: "6.0.0", latest_version: "8.0.0")
      assert_equal 70, score.value
      assert_equal "warning", score.status
    end

    test "minor versions behind subtract 3 each capped at 15" do
      score = build_score(locked_version: "1.0.0", latest_version: "1.6.0")
      # 6 minor versions * 3 = 18, capped at 15
      assert_equal 85, score.value
      assert_equal "healthy", score.status
    end

    test "staleness penalty for 200 days" do
      versions = [{ number: "1.0.0", created_at: (Time.now - 200 * 86400).iso8601, downloads: 1000 }]
      score = build_score(versions: versions)
      assert_equal 95, score.value
    end

    test "staleness penalty for 400 days" do
      versions = [{ number: "1.0.0", created_at: (Time.now - 400 * 86400).iso8601, downloads: 1000 }]
      score = build_score(versions: versions)
      assert_equal 90, score.value
    end

    test "staleness penalty for 800 days" do
      versions = [{ number: "1.0.0", created_at: (Time.now - 800 * 86400).iso8601, downloads: 1000 }]
      score = build_score(versions: versions)
      assert_equal 80, score.value
    end

    test "yanked gem scores 0" do
      score = build_score(yanked: true)
      assert_equal 0, score.value
      assert_equal "critical", score.status
      assert_includes score.reasons, "Yanked from RubyGems.org"
    end

    test "unknown status when rubygems_data is nil" do
      score = HealthScore.new(gem_name: "local_gem", locked_version: "0.1.0", rubygems_data: nil)
      assert_nil score.value
      assert_equal "unknown", score.status
      assert_includes score.reasons, "No API data available"
    end

    test "status thresholds" do
      assert_equal "healthy", build_score(locked_version: "1.0.0", latest_version: "1.0.0").status
      assert_equal "warning", build_score(locked_version: "6.0.0", latest_version: "8.0.0").status
      # Critical: score < 50
      advisories = [{ cve: "CVE-2024-0002", cvss_v3: 7.5 }, { cve: "CVE-2024-0003", cvss_v3: 7.5 }]
      assert_equal "critical", build_score(advisories: advisories).status
    end

    test "reasons lists all penalties" do
      advisories = [{ cve: "CVE-2024-0002", cvss_v3: 7.5, title: "High vuln" }]
      score = build_score(advisories: advisories, locked_version: "1.0.0", latest_version: "2.0.0")
      assert score.reasons.any? { |r| r.include?("high CVE") }
      assert score.reasons.any? { |r| r.include?("major version") }
    end

    test "score never goes below 0" do
      advisories = (1..10).map { |i| { cve: "CVE-2024-#{i}", cvss_v3: 5.0, title: "Medium #{i}" } }
      score = build_score(advisories: advisories)
      assert_operator score.value, :>=, 0
    end

    private

    def build_score(
      locked_version: "1.0.0",
      latest_version: "1.0.0",
      advisories: [],
      yanked: false,
      versions: nil
    )
      versions ||= [{ number: latest_version, created_at: Time.now.iso8601, downloads: 1000 }]
      rubygems_data = {
        name: "test_gem",
        latest_version: latest_version,
        versions: versions,
        licenses: ["MIT"],
        homepage_uri: nil,
        source_code_uri: nil,
        yanked: yanked
      }
      HealthScore.new(
        gem_name: "test_gem",
        locked_version: locked_version,
        rubygems_data: rubygems_data,
        advisories: advisories
      )
    end
  end
end

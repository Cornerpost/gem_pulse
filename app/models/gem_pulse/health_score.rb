module GemPulse
  class HealthScore
    attr_reader :gem_name, :locked_version, :rubygems_data, :advisories

    def initialize(gem_name:, locked_version:, rubygems_data:, advisories: [])
      @gem_name = gem_name
      @locked_version = locked_version
      @rubygems_data = rubygems_data
      @advisories = advisories || []
    end

    def value
      @value ||= compute_score
    end

    def status
      @status ||= compute_status
    end

    def reasons
      @reasons ||= compute_reasons
    end

    private

    def compute_score
      return nil if unknown?
      return 0 if yanked?

      score = 100

      critical_cves, high_cves, medium_cves, low_cves = categorize_advisories
      return 0 unless critical_cves.empty?

      high_cves.each { score = [score - 50, 5].max }
      medium_cves.each { |_| score -= 25 }
      low_cves.each { |_| score -= 10 }

      score -= major_versions_behind * 15
      score -= [minor_versions_behind * 3, 15].min
      score -= staleness_penalty

      [score, 0].max
    end

    def compute_status
      return "unknown" if unknown?
      return "critical" if value < 50
      return "warning" if value < 80
      "healthy"
    end

    def compute_reasons
      return ["No API data available"] if unknown?

      result = []
      result << "Yanked from RubyGems.org" if yanked?

      critical_cves, high_cves, medium_cves, low_cves = categorize_advisories
      result << "#{critical_cves.size} critical CVE(s): #{cve_ids(critical_cves)}" if critical_cves.any?
      result << "#{high_cves.size} high CVE(s): #{cve_ids(high_cves)}" if high_cves.any?
      result << "#{medium_cves.size} medium CVE(s): #{cve_ids(medium_cves)}" if medium_cves.any?
      result << "#{low_cves.size} low CVE(s): #{cve_ids(low_cves)}" if low_cves.any?

      if major_versions_behind > 0
        result << "#{major_versions_behind} major version(s) behind latest (#{latest_version})"
      end
      if minor_versions_behind > 0
        result << "#{minor_versions_behind} minor version(s) behind latest (#{latest_version})"
      end

      days = days_since_last_release
      if days && days > 180
        result << "Last release #{days} days ago"
      end

      result << "No issues detected" if result.empty?
      result
    end

    def unknown?
      rubygems_data.nil?
    end

    def yanked?
      rubygems_data&.dig(:yanked) == true
    end

    def categorize_advisories
      critical = []
      high = []
      medium = []
      low = []

      advisories.each do |adv|
        cvss = adv[:cvss_v3] || 0
        case
        when cvss >= 9.0 then critical << adv
        when cvss >= 7.0 then high << adv
        when cvss >= 4.0 then medium << adv
        else low << adv
        end
      end

      [critical, high, medium, low]
    end

    def cve_ids(advs)
      advs.map { |a| a[:cve] || a[:ghsa] }.compact.join(", ")
    end

    def latest_version
      rubygems_data&.dig(:latest_version)
    end

    def major_versions_behind
      return 0 if unknown? || latest_version.nil?
      locked = Gem::Version.new(locked_version)
      latest = Gem::Version.new(latest_version)
      latest_segments = latest.segments
      locked_segments = locked.segments
      diff = (latest_segments[0] || 0) - (locked_segments[0] || 0)
      [diff, 0].max
    end

    def minor_versions_behind
      return 0 if unknown? || latest_version.nil?
      locked = Gem::Version.new(locked_version)
      latest = Gem::Version.new(latest_version)
      return 0 if major_versions_behind > 0
      diff = (latest.segments[1] || 0) - (locked.segments[1] || 0)
      [diff, 0].max
    end

    def days_since_last_release
      versions = rubygems_data&.dig(:versions)
      return nil if versions.nil? || versions.empty?
      latest_release = versions.first
      release_date = latest_release[:created_at]
      return nil unless release_date
      date = release_date.is_a?(String) ? Time.parse(release_date) : release_date
      ((Time.now - date) / 86400).to_i
    end

    def staleness_penalty
      days = days_since_last_release
      return 0 if days.nil? || days < 180
      return 5 if days < 365
      return 10 if days < 730
      20
    end
  end
end

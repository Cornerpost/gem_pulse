require "bundler/audit/scanner"

module GemPulse
  class AdvisoryScanner
    attr_reader :app_root

    def initialize(app_root: Rails.root)
      @app_root = Pathname.new(app_root)
    end

    def advisories
      @advisories ||= scan_advisories
    end

    private

    def scan_advisories
      result = Hash.new { |h, k| h[k] = [] }

      scanner = Bundler::Audit::Scanner.new(app_root.to_s)
      scanner.scan do |scan_result|
        case scan_result
        when Bundler::Audit::Results::InsecureSource
          next
        when Bundler::Audit::Results::UnpatchedGem
          gem_name = scan_result.gem.name
          advisory = scan_result.advisory

          result[gem_name] << normalize_advisory(advisory)
        end
      end

      result
    end

    def normalize_advisory(advisory)
      h = advisory.to_h

      cvss = (h[:cvss_v3] || h[:cvss_v2] || 0).to_f

      {
        cve: h[:cve],
        ghsa: h[:ghsa],
        url: h[:url],
        title: h[:title],
        description: h[:description],
        cvss_v3: cvss,
        severity: severity_from_cvss(cvss),
        patched_versions: (h[:patched_versions] || []).map(&:to_s),
        unaffected_versions: (h[:unaffected_versions] || []).map(&:to_s)
      }
    end

    def severity_from_cvss(cvss)
      case
      when cvss >= 9.0 then "critical"
      when cvss >= 7.0 then "high"
      when cvss >= 4.0 then "medium"
      when cvss > 0    then "low"
      else "unknown"
      end
    end
  end
end

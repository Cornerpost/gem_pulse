module GemPulse
  class DashboardController < ApplicationController
    def index
      @gems = load_gem_health
      @summary = compute_summary(@gems)
      @graph_stats = dependency_graph.stats
      @category_summary = gem_categorizer(@gems).summary
    end

    private

      def compute_summary(gems)
        scored_gems = gems.reject { |g| g[:status] == "unknown" }

        {
          total: gems.size,
          with_cves: gems.count { |g| g[:advisories].any? },
          outdated: scored_gems.count { |g| g[:score] && g[:score] < 80 },
          aggregate_score: scored_gems.any? ? (scored_gems.sum { |g| g[:score] } / scored_gems.size.to_f).round : nil
        }
      end
  end
end

module GemPulse
  class GraphController < ApplicationController
    def index
      @gems = load_gem_health
      @graph = dependency_graph
      @categorizer = gem_categorizer(@gems)

      # Build a lookup of health status by gem name
      health_by_name = @gems.each_with_object({}) { |g, h| h[g[:name]] = g[:status] }

      # Enhance the graph JSON with health status and category
      json_graph = @graph.to_json_graph
      json_graph[:nodes].each do |node|
        node[:status] = health_by_name[node[:id]] || "unknown"
        node[:category] = @categorizer.categorize(node[:id])
      end

      @graph_json = json_graph.to_json
      @stats = @graph.stats
    end
  end
end

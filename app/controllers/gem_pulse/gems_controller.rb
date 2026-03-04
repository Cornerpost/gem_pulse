module GemPulse
  class GemsController < ApplicationController
    def index
      @gems = load_gem_health
      @categorizer = gem_categorizer(@gems)
      @graph = dependency_graph
      @gems = filter_gems(@gems, params[:status])
      @gems = filter_by_category(@gems, params[:category])
      @gems = sort_gems(@gems, params[:sort], params[:direction])
    end

    def show
      @gem_name = params[:name]
      all_gems = load_gem_health
      @gem = all_gems.find { |g| g[:name] == @gem_name }

      if @gem.nil?
        render plain: "Gem not found", status: :not_found
        return
      end

      @versions = @gem[:rubygems_data]&.dig(:versions)&.first(10) || []

      # Dependency intelligence
      @graph = dependency_graph
      @category = gem_categorizer(all_gems).categorize(@gem_name)
      @is_direct = @graph.direct?(@gem_name)
      @dep_trace = @graph.trace(@gem_name)
      @dependents = @graph.dependents(@gem_name)
      @sub_deps = @graph.dependencies(@gem_name)
      @impact = @graph.impact(@gem_name)
      @subtree_size = @graph.subtree_size(@gem_name)
      @depth = @graph.depth(@gem_name)
    end

    private

      SORTABLE_COLUMNS = %w[name score status locked_version latest_version].freeze

      def sort_gems(gems, column, direction)
        column = SORTABLE_COLUMNS.include?(column) ? column : "name"
        direction = direction == "desc" ? :desc : :asc

        sorted = gems.sort_by do |g|
          val = g[column.to_sym]
          case column
          when "score"
            val || -1
          else
            val.to_s.downcase
          end
        end

        direction == :desc ? sorted.reverse : sorted
      end

      def filter_gems(gems, status)
        return gems if status.blank?
        valid_statuses = %w[critical warning healthy unknown]
        return gems unless valid_statuses.include?(status)
        gems.select { |g| g[:status] == status }
      end

      def filter_by_category(gems, category)
        return gems if category.blank?
        categorizer = gem_categorizer(gems)
        gems.select { |g| categorizer.categorize(g[:name]) == category }
      end
  end
end

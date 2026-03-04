module GemPulse
  class DependencyGraph
    attr_reader :app_root

    def initialize(app_root: Rails.root)
      @app_root = Pathname.new(app_root)
    end

    # All gem names declared directly in the Gemfile
    def direct_dependency_names
      @direct_dependency_names ||= begin
        content = lockfile_path.read
        parser = Bundler::LockfileParser.new(content)
        # DEPENDENCIES section lists gems declared in Gemfile
        parser.dependencies.keys.to_set
      end
    end

    # Is this gem declared directly in the Gemfile?
    def direct?(gem_name)
      direct_dependency_names.include?(gem_name)
    end

    # What does this gem depend on? (forward edges — children)
    def dependencies(gem_name)
      forward_edges[gem_name] || []
    end

    # What depends on this gem? (reverse edges — parents)
    def dependents(gem_name)
      reverse_edges[gem_name] || []
    end

    # Trace a gem back to the Gemfile entries that cause it to be included.
    # Returns an array of paths, where each path is an array of gem names
    # from a direct dependency down to the target gem.
    #
    #   trace("rack") => [["rails", "actionpack", "rack"], ["puma", "rack"]]
    #
    def trace(gem_name)
      return [[gem_name]] if direct?(gem_name)

      paths = []
      visited = Set.new

      find_paths_to_root(gem_name, [gem_name], visited, paths)
      paths
    end

    # How many gems in the entire transitive subtree rooted at this gem?
    # (not counting itself)
    def subtree_size(gem_name)
      count_subtree(gem_name, Set.new) - 1
    end

    # Depth from a Gemfile root. Direct deps = 0, their deps = 1, etc.
    # Returns nil if the gem isn't in the graph.
    def depth(gem_name)
      depths[gem_name]
    end

    # How many gems depend on this one (directly or transitively)?
    # High values = high impact if this gem has a problem.
    def impact(gem_name)
      count_reverse_subtree(gem_name, Set.new) - 1
    end

    # All gem names in the graph
    def all_gems
      specs_by_name.keys
    end

    # Summary statistics about the dependency graph
    def stats
      direct_count = direct_dependency_names.size
      total = all_gems.size
      transitive_count = total - direct_count

      max_depth_val = depths.values.compact.max || 0

      heaviest = direct_dependency_names
        .map { |name| [name, subtree_size(name)] }
        .max_by(&:last)

      most_depended = all_gems
        .map { |name| [name, impact(name)] }
        .max_by(&:last)

      {
        direct: direct_count,
        transitive: transitive_count,
        total: total,
        max_depth: max_depth_val,
        heaviest_name: heaviest&.first,
        heaviest_count: heaviest&.last || 0,
        most_depended_name: most_depended&.first,
        most_depended_count: most_depended&.last || 0
      }
    end

    # Returns the graph as JSON-serializable data for D3.js visualization.
    # Nodes: { id, version, direct, depth, subtree_size, impact }
    # Links: { source, target }
    def to_json_graph
      nodes = all_gems.map do |name|
        spec = specs_by_name[name]
        {
          id: name,
          version: spec&.version&.to_s,
          direct: direct?(name),
          depth: depth(name) || 0,
          subtree_size: subtree_size(name),
          impact: impact(name)
        }
      end

      links = []
      forward_edges.each do |source, targets|
        targets.each do |target|
          links << { source: source, target: target }
        end
      end

      { nodes: nodes, links: links }
    end

    private

    def lockfile_path
      app_root.join("Gemfile.lock")
    end

    def specs_by_name
      @specs_by_name ||= begin
        content = lockfile_path.read
        parser = Bundler::LockfileParser.new(content)
        parser.specs.index_by(&:name)
      end
    end

    # Forward edges: gem_name => [dependency names]
    def forward_edges
      @forward_edges ||= begin
        edges = {}
        specs_by_name.each do |name, spec|
          deps = spec.dependencies.map(&:name).select { |d| specs_by_name.key?(d) }
          edges[name] = deps unless deps.empty?
        end
        edges
      end
    end

    # Reverse edges: gem_name => [names of gems that depend on it]
    def reverse_edges
      @reverse_edges ||= begin
        edges = Hash.new { |h, k| h[k] = [] }
        forward_edges.each do |source, targets|
          targets.each { |target| edges[target] << source }
        end
        edges
      end
    end

    # BFS to compute depth of each gem from any Gemfile root
    def depths
      @depths ||= begin
        result = {}
        queue = []

        direct_dependency_names.each do |name|
          next unless specs_by_name.key?(name)
          result[name] = 0
          queue << name
        end

        while (current = queue.shift)
          current_depth = result[current]
          dependencies(current).each do |dep|
            unless result.key?(dep)
              result[dep] = current_depth + 1
              queue << dep
            end
          end
        end

        result
      end
    end

    # DFS to trace paths from target back up to Gemfile roots
    def find_paths_to_root(gem_name, current_path, visited, paths)
      return if visited.include?(gem_name)
      visited.add(gem_name)

      parents = dependents(gem_name)
      if parents.empty?
        # This is a root (or orphan), but not necessarily in Gemfile
        return
      end

      parents.each do |parent|
        new_path = [parent] + current_path
        if direct?(parent)
          paths << new_path
        else
          find_paths_to_root(parent, new_path, visited.dup, paths)
        end
      end
    end

    # Count all nodes in the subtree (forward direction)
    def count_subtree(gem_name, visited)
      return 0 if visited.include?(gem_name)
      visited.add(gem_name)

      count = 1
      dependencies(gem_name).each do |dep|
        count += count_subtree(dep, visited)
      end
      count
    end

    # Count all nodes in the reverse subtree (what depends on this)
    def count_reverse_subtree(gem_name, visited)
      return 0 if visited.include?(gem_name)
      visited.add(gem_name)

      count = 1
      dependents(gem_name).each do |dep|
        count += count_reverse_subtree(dep, visited)
      end
      count
    end
  end
end

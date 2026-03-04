require "test_helper"

module GemPulse
  class DependencyGraphTest < ActiveSupport::TestCase
    setup do
      @fixture_root = File.expand_path("../../fixtures/files", __dir__)
      @graph = DependencyGraph.new(app_root: @fixture_root)
    end

    # ── Direct vs transitive ──

    test "identifies direct dependencies from Gemfile" do
      assert @graph.direct?("rails")
      assert @graph.direct?("nokogiri")
      assert @graph.direct?("puma")
      assert @graph.direct?("local_gem")
      assert @graph.direct?("git_gem")
    end

    test "identifies transitive dependencies" do
      refute @graph.direct?("rack")
      refute @graph.direct?("racc")
      refute @graph.direct?("actionpack")
      refute @graph.direct?("activesupport")
    end

    # ── Forward edges (dependencies) ──

    test "returns dependencies of a gem" do
      deps = @graph.dependencies("rails")
      assert_includes deps, "actioncable"
      assert_includes deps, "actionpack"
      assert_includes deps, "activesupport"
    end

    test "returns dependencies of nokogiri" do
      deps = @graph.dependencies("nokogiri")
      assert_includes deps, "racc"
    end

    test "leaf gems have no dependencies" do
      deps = @graph.dependencies("racc")
      assert_empty deps
    end

    # ── Reverse edges (dependents) ──

    test "returns dependents of a gem" do
      dependents = @graph.dependents("activesupport")
      assert_includes dependents, "rails"
      assert_includes dependents, "actionpack"
    end

    test "returns dependents of rack" do
      dependents = @graph.dependents("rack")
      assert_includes dependents, "actionpack"
    end

    test "root gems have no dependents" do
      dependents = @graph.dependents("puma")
      assert_empty dependents
    end

    # ── Trace ──

    test "trace of a direct dependency returns itself" do
      paths = @graph.trace("rails")
      assert_equal [["rails"]], paths
    end

    test "trace of a transitive dependency returns paths to roots" do
      paths = @graph.trace("rack")
      # rack is pulled in by actionpack, which is pulled in by rails (and actioncable)
      assert paths.any? { |path| path.first == "rails" && path.last == "rack" }
    end

    test "trace of racc goes through nokogiri" do
      paths = @graph.trace("racc")
      assert paths.any? { |path| path.include?("nokogiri") && path.last == "racc" }
    end

    # ── Subtree size ──

    test "subtree size of a leaf gem is 0" do
      assert_equal 0, @graph.subtree_size("racc")
    end

    test "subtree size of nokogiri includes racc" do
      assert @graph.subtree_size("nokogiri") >= 1
    end

    test "subtree size of rails is largest" do
      rails_size = @graph.subtree_size("rails")
      nokogiri_size = @graph.subtree_size("nokogiri")
      assert rails_size > nokogiri_size
    end

    # ── Depth ──

    test "direct dependencies have depth 0" do
      assert_equal 0, @graph.depth("rails")
      assert_equal 0, @graph.depth("nokogiri")
      assert_equal 0, @graph.depth("puma")
    end

    test "transitive deps have depth > 0" do
      assert @graph.depth("actionpack") > 0
      assert @graph.depth("rack") > 0
    end

    test "racc is deeper than nokogiri" do
      assert @graph.depth("racc") > @graph.depth("nokogiri")
    end

    # ── Impact ──

    test "impact of activesupport is high" do
      # actionpack, actioncable, and rails all depend on activesupport
      assert @graph.impact("activesupport") >= 2
    end

    test "impact of a leaf with no dependents is 0" do
      assert_equal 0, @graph.impact("puma")
    end

    # ── Stats ──

    test "stats returns correct structure" do
      stats = @graph.stats
      assert_kind_of Integer, stats[:direct]
      assert_kind_of Integer, stats[:transitive]
      assert_kind_of Integer, stats[:total]
      assert_equal stats[:direct] + stats[:transitive], stats[:total]
      assert stats[:direct] > 0
      assert stats[:total] > stats[:direct]
      assert_not_nil stats[:heaviest_name]
      assert_not_nil stats[:most_depended_name]
    end

    # ── JSON graph ──

    test "to_json_graph returns nodes and links" do
      json = @graph.to_json_graph
      assert json.key?(:nodes)
      assert json.key?(:links)
      assert json[:nodes].any?
      assert json[:links].any?

      node = json[:nodes].find { |n| n[:id] == "rails" }
      assert_not_nil node
      assert_equal true, node[:direct]
      assert_equal 0, node[:depth]

      link = json[:links].find { |l| l[:source] == "rails" && l[:target] == "actionpack" }
      assert_not_nil link
    end
  end
end

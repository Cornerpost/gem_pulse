require "test_helper"

module GemPulse
  class GemInspectorTest < ActiveSupport::TestCase
    setup do
      @fixture_root = File.expand_path("../../fixtures/files", __dir__)
      @inspector = GemInspector.new(app_root: @fixture_root)
    end

    test "returns gems from lockfile" do
      gems = @inspector.gems
      names = gems.map(&:name)
      assert_includes names, "rails"
      assert_includes names, "nokogiri"
      assert_includes names, "puma"
    end

    test "returns correct locked versions" do
      gems = @inspector.gems
      rails = gems.find { |g| g.name == "rails" }
      assert_equal "8.1.2", rails.locked_version

      nokogiri = gems.find { |g| g.name == "nokogiri" }
      assert_equal "1.16.4", nokogiri.locked_version
    end

    test "flags path gems with source :path" do
      gems = @inspector.gems
      local = gems.find { |g| g.name == "local_gem" }
      assert_not_nil local, "local_gem should be in the gem list"
      assert_equal :path, local.source
    end

    test "flags git gems with source :git" do
      gems = @inspector.gems
      git = gems.find { |g| g.name == "git_gem" }
      assert_not_nil git, "git_gem should be in the gem list"
      assert_equal :git, git.source
    end

    test "rubygems gems have source :rubygems" do
      gems = @inspector.gems
      rails = gems.find { |g| g.name == "rails" }
      assert_equal :rubygems, rails.source
    end

    test "includes transitive dependencies from lockfile" do
      gems = @inspector.gems
      names = gems.map(&:name)
      assert_includes names, "rack"
      assert_includes names, "racc"
    end

    test "returns declared version for direct dependencies" do
      gems = @inspector.gems
      nokogiri = gems.find { |g| g.name == "nokogiri" }
      assert_equal "~> 1.16", nokogiri.declared_version
    end
  end
end

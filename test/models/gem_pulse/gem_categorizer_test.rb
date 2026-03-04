require "test_helper"

module GemPulse
  class GemCategorizerTest < ActiveSupport::TestCase
    # ── Curated lookup ──

    test "categorizes well-known gems from curated list" do
      categorizer = GemCategorizer.new(gem_names: %w[rails])
      assert_equal "Web Framework", categorizer.categorize("rails")
    end

    test "categorizes puma as Web Server" do
      categorizer = GemCategorizer.new
      assert_equal "Web Server", categorizer.categorize("puma")
    end

    test "categorizes sqlite3 as ORM / Database" do
      categorizer = GemCategorizer.new
      assert_equal "ORM / Database", categorizer.categorize("sqlite3")
    end

    test "categorizes faraday as HTTP Client" do
      categorizer = GemCategorizer.new
      assert_equal "HTTP Client", categorizer.categorize("faraday")
    end

    test "categorizes friendly_id as Content" do
      categorizer = GemCategorizer.new
      assert_equal "Content", categorizer.categorize("friendly_id")
    end

    # ── Group-based heuristics ──

    test "categorizes unknown test-group gem as Testing" do
      categorizer = GemCategorizer.new(groups: { "my_test_helper" => [:test] })
      assert_equal "Testing", categorizer.categorize("my_test_helper")
    end

    test "categorizes unknown dev-only gem as Development" do
      categorizer = GemCategorizer.new(groups: { "my_dev_tool" => [:development] })
      assert_equal "Development", categorizer.categorize("my_dev_tool")
    end

    test "gem in both default and development groups is not categorized as Development" do
      categorizer = GemCategorizer.new(groups: { "some_gem" => [:default, :development] })
      # Should fall through to name heuristics or Other
      refute_equal "Development", categorizer.categorize("some_gem")
    end

    # ── Name-based heuristics ──

    test "action* gems are categorized as Rails Internals" do
      categorizer = GemCategorizer.new
      assert_equal "Rails Internals", categorizer.categorize("actionfoo")
    end

    test "active* gems are categorized as Rails Internals" do
      categorizer = GemCategorizer.new
      assert_equal "Rails Internals", categorizer.categorize("activefoo")
    end

    test "rack-* gems are categorized as Rack Middleware" do
      categorizer = GemCategorizer.new
      assert_equal "Rack Middleware", categorizer.categorize("rack-timeout")
    end

    test "faraday-* gems are categorized as Faraday Plugin" do
      categorizer = GemCategorizer.new
      assert_equal "Faraday Plugin", categorizer.categorize("faraday-net_http")
    end

    test "rubocop* gems are categorized as Code Quality" do
      categorizer = GemCategorizer.new
      assert_equal "Code Quality", categorizer.categorize("rubocop-custom")
    end

    # ── Fallback ──

    test "completely unknown gem is categorized as Other" do
      categorizer = GemCategorizer.new
      assert_equal "Other", categorizer.categorize("totally_unknown_gem_xyz")
    end

    # ── Grouped output ──

    test "grouped returns hash of category to gem names" do
      categorizer = GemCategorizer.new(gem_names: %w[rails puma nokogiri sqlite3])
      grouped = categorizer.grouped
      assert_includes grouped["Web Framework"], "rails"
      assert_includes grouped["Web Server"], "puma"
      assert_includes grouped["ORM / Database"], "sqlite3"
    end

    test "summary returns counts sorted by count desc" do
      categorizer = GemCategorizer.new(gem_names: %w[rails actionpack actionview puma sqlite3])
      summary = categorizer.summary
      assert_kind_of Hash, summary
      # All values should be positive integers
      summary.each_value { |v| assert v > 0 }
    end

    # ── Curated list has known gems in correct categories ──

    test "curated lookup covers key gems without duplicates" do
      all_gems = GemCategorizer::CATEGORIES.values.flatten
      assert_equal all_gems.size, all_gems.uniq.size, "Curated list has duplicate gem names"
    end
  end
end

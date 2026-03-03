require "test_helper"
require "webmock/minitest"

class GemsTest < ActionDispatch::IntegrationTest
  setup do
    stub_request(:get, /rubygems\.org\/api/).to_return(status: 404, body: "")
    @inspector = GemPulse::GemInspector.new(app_root: Bundler.root)
  end

  # ---- Index ----

  test "GET /gem_pulse/gems returns 200" do
    get gem_pulse.gems_path
    assert_response :success
  end

  test "gems index contains gem names from lockfile" do
    get gem_pulse.gems_path
    gem_name = @inspector.gems.find { |g| g.source == :rubygems }&.name
    assert_select "table.gp-table tbody td a", text: gem_name if gem_name
  end

  test "gems index renders filter links" do
    get gem_pulse.gems_path
    assert_select ".gp-filters .gp-filter", minimum: 5
    assert_select ".gp-filter", text: "All"
    assert_select ".gp-filter", text: "Critical"
    assert_select ".gp-filter", text: "Warning"
    assert_select ".gp-filter", text: "Healthy"
    assert_select ".gp-filter", text: "Unknown"
  end

  test "gems index renders sortable column headers" do
    get gem_pulse.gems_path
    assert_select "table.gp-table thead th", minimum: 5
  end

  test "sort by name ascending" do
    get gem_pulse.gems_path(sort: "name", direction: "asc")
    assert_response :success
    names = css_select("table.gp-table tbody td a").map(&:text)
    assert_equal names, names.sort
  end

  test "sort by name descending" do
    get gem_pulse.gems_path(sort: "name", direction: "desc")
    assert_response :success
    names = css_select("table.gp-table tbody td a").map(&:text)
    assert_equal names, names.sort.reverse
  end

  test "filter by unknown status shows only unknown gems" do
    get gem_pulse.gems_path(status: "unknown")
    assert_response :success
    badges = css_select(".gp-badge").map(&:text).map(&:strip)
    badges.each do |badge|
      assert_equal "unknown", badge
    end
  end

  test "filter by invalid status shows all gems" do
    get gem_pulse.gems_path(status: "bogus")
    assert_response :success
    all_count = @inspector.gems.size
    row_count = css_select("table.gp-table tbody tr").size
    assert_equal all_count, row_count
  end

  test "active filter has active class" do
    get gem_pulse.gems_path(status: "unknown")
    assert_select ".gp-filter-active", text: "Unknown"
  end

  test "sort params preserved when filtering" do
    get gem_pulse.gems_path(sort: "score", direction: "desc", status: "unknown")
    assert_response :success
  end

  # ---- Show ----

  test "GET /gem_pulse/gems/:name returns 200 for existing gem" do
    gem_name = @inspector.gems.first.name
    get gem_pulse.gem_path(gem_name)
    assert_response :success
  end

  test "show page displays gem name as heading" do
    gem_name = @inspector.gems.first.name
    get gem_pulse.gem_path(gem_name)
    assert_select "h1", gem_name
  end

  test "show page has status badge" do
    gem_name = @inspector.gems.first.name
    get gem_pulse.gem_path(gem_name)
    assert_select ".gp-gem-header .gp-badge"
  end

  test "show page has score breakdown" do
    gem_name = @inspector.gems.first.name
    get gem_pulse.gem_path(gem_name)
    assert_select "h2", "Score Breakdown"
    assert_select ".gp-reasons li", minimum: 1
  end

  test "show page has back link to gems index" do
    gem_name = @inspector.gems.first.name
    get gem_pulse.gem_path(gem_name)
    assert_select "a[href='#{gem_pulse.gems_path}']"
  end

  test "GET /gem_pulse/gems/nonexistent returns 404" do
    get gem_pulse.gem_path("definitely_not_a_real_gem_name_xyz")
    assert_response :not_found
  end

  test "show page renders locked version" do
    gem_entry = @inspector.gems.first
    get gem_pulse.gem_path(gem_entry.name)
    assert_includes response.body, gem_entry.locked_version
  end
end

require "test_helper"
require "webmock/minitest"

class DashboardTest < ActionDispatch::IntegrationTest
  setup do
    stub_request(:get, /rubygems\.org\/api/).to_return(status: 404, body: "")
  end

  test "GET /gem_pulse returns 200" do
    get gem_pulse.root_path
    assert_response :success
  end

  test "displays configured title" do
    get gem_pulse.root_path
    assert_select "h1", GemPulse.configuration.title
  end

  test "renders summary cards" do
    get gem_pulse.root_path
    assert_select ".gp-summary-cards .gp-card", minimum: 4
  end

  test "summary cards contain labels" do
    get gem_pulse.root_path
    assert_select ".gp-card-label", text: "Total Gems"
    assert_select ".gp-card-label", text: "With CVEs"
    assert_select ".gp-card-label", text: "Outdated"
    assert_select ".gp-card-label", text: "Aggregate Score"
  end

  test "dependency structure cards are present" do
    get gem_pulse.root_path
    assert_select ".gp-card-label", text: "Direct Deps"
    assert_select ".gp-card-label", text: "Transitive"
    assert_select ".gp-card-label", text: "Max Depth"
  end

  test "category breakdown is present" do
    get gem_pulse.root_path
    assert_select "h2", "Gem Categories"
    assert_select ".gp-category-bars"
    assert_select ".gp-category-row", minimum: 1
  end

  test "total gems card shows a number" do
    get gem_pulse.root_path
    assert_select ".gp-card" do |cards|
      total_card = cards.find { |c| c.css(".gp-card-label").text == "Total Gems" }
      value = total_card.css(".gp-card-value").text.strip.to_i
      assert value > 0, "Total gems should be greater than 0"
    end
  end

  test "needs attention table is present" do
    get gem_pulse.root_path
    assert_select "h2", "Needs Attention"
    assert_select "table.gp-table"
  end

  test "needs attention table renders rows when scored gems exist" do
    stub_rubygems_success("rails")
    get gem_pulse.root_path
    assert_select "table.gp-table tbody td a[href]"
    assert_select ".gp-badge"
  end

  test "needs attention table is gracefully empty when all gems are unknown" do
    # With all API calls returning 404, all gems are "unknown" and filtered out
    get gem_pulse.root_path
    assert_select "table.gp-table tbody tr", 0
  end

  test "nav contains links to dashboard and gems" do
    get gem_pulse.root_path
    assert_select "header nav a", minimum: 2
    assert_select "header nav a[href='#{gem_pulse.gems_path}']"
  end

  private

  def stub_rubygems_success(gem_name)
    # Override the blanket 404 stub for this specific gem
    stub_request(:get, "https://rubygems.org/api/v2/rubygems/#{gem_name}/versions/latest.json")
      .to_return(
        status: 200,
        body: { name: gem_name, version: "8.1.2", licenses: ["MIT"], yanked: false }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
    stub_request(:get, "https://rubygems.org/api/v1/versions/#{gem_name}.json")
      .to_return(
        status: 200,
        body: [{ number: "8.1.2", created_at: Time.now.iso8601, downloads_count: 50000 }].to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end
end

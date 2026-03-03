require "test_helper"
require "webmock/minitest"

class NavigationTest < ActionDispatch::IntegrationTest
  setup do
    # Stub all RubyGems.org API calls so controllers don't hit the network
    stub_request(:get, /rubygems\.org\/api/).to_return(status: 404, body: "")
  end

  test "dashboard loads successfully" do
    get gem_pulse.root_path
    assert_response :success
    assert_select "h1", gem_pulse_config_title
  end

  test "gems index loads successfully" do
    get gem_pulse.gems_path
    assert_response :success
    assert_select "table.gp-table"
  end

  test "gems index with status filter" do
    get gem_pulse.gems_path(status: "unknown")
    assert_response :success
  end

  test "gems index with sort params" do
    get gem_pulse.gems_path(sort: "name", direction: "desc")
    assert_response :success
  end

  test "gems show for existing gem" do
    inspector = GemPulse::GemInspector.new(app_root: Bundler.root)
    gem_name = inspector.gems.first.name

    get gem_pulse.gem_path(gem_name)
    assert_response :success
    assert_select "h1", gem_name
  end

  test "gems show for nonexistent gem returns 404" do
    get gem_pulse.gem_path("definitely_not_a_real_gem_name")
    assert_response :not_found
  end

  private

  def gem_pulse_config_title
    GemPulse.configuration.title
  end
end

require "test_helper"
require "webmock/minitest"

class GraphTest < ActionDispatch::IntegrationTest
  setup do
    stub_request(:get, /rubygems\.org\/api/).to_return(status: 404, body: "")
  end

  test "GET /gem_pulse/graph returns 200" do
    get gem_pulse.graph_path
    assert_response :success
  end

  test "graph page has D3 script tag" do
    get gem_pulse.graph_path
    assert_select "script[src*='d3']"
  end

  test "graph page renders container" do
    get gem_pulse.graph_path
    assert_select "#gp-graph-container"
  end

  test "graph page has legend" do
    get gem_pulse.graph_path
    assert_select ".gp-graph-legend"
  end

  test "graph page has controls" do
    get gem_pulse.graph_path
    assert_select ".gp-graph-controls"
    assert_select "#gp-search"
  end

  test "graph page embeds JSON data" do
    get gem_pulse.graph_path
    assert_match(/"nodes"/, response.body)
    assert_match(/"links"/, response.body)
  end

  test "graph stats are displayed" do
    get gem_pulse.graph_path
    assert_select ".gp-graph-stats"
    assert_match(/direct/, response.body)
    assert_match(/transitive/, response.body)
  end
end

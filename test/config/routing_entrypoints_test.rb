# typed: false
# frozen_string_literal: true

require "test_helper"

class RoutingEntrypointsTest < ActiveSupport::TestCase
  test "global routing entrypoints are loaded" do
    assert_nothing_raised { Rails.application.reload_routes! }

    root_route = Rails.application.routes.recognize_path("/")

    assert_equal "inertia_example", root_route[:controller]
    assert_equal "index", root_route[:action]
  end

  test "future routing namespace files exist" do
    %w(core line post).each do |name|
      assert_predicate Rails.root.join("config/routing/#{name}.rb"), :exist?, "missing config/routing/#{name}.rb"
    end
  end
end

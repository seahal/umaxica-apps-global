# typed: false
# frozen_string_literal: true

require "test_helper"

class RoutingEntrypointsTest < ActiveSupport::TestCase
  test "global routing entrypoints are loaded" do
    assert_nothing_raised { Rails.application.reload_routes! }

    root_route = Rails.application.routes.recognize_path(
      "http://#{ENV.fetch(
        "ACME_SERVICE_URL",
        "www.app.localhost",
      )}/",
    )

    assert_equal "acme/app/roots", root_route[:controller]
    assert_equal "index", root_route[:action]
  end

  test "future routing namespace files exist" do
    %w(core line).each do |name|
      assert_predicate Rails.root.join("config/routes/#{name}.rb"), :exist?, "missing config/routes/#{name}.rb"
    end
  end
end

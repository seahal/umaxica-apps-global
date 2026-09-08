# typed: false
# frozen_string_literal: true

require "test_helper"

# Published static GET routes must reach an HTTP boundary without an unhandled exception.
class StaticGetRouteResponseTest < ActionDispatch::IntegrationTest
  HOST = "auth.app.localhost"
  SKIP = %r{/(callback|oauth|social|action_mailbox|conductor|historical_location)\\b}

  test "static GET routes do not produce an unhandled server error" do
    host! HOST
    failures = []
    static_get_paths.each do |path|
      get(path)
      failures << "GET #{path}: #{response.status}" if response.status >= 500
    rescue StandardError => e
      failures << "GET #{path}: #{e.class}: #{e.message}"
    end

    assert_empty failures, failures.join("\n")
  end

  private

  def static_get_paths
    Rails.application.routes.routes.select { |route|
      route.verb == "GET"
    }.map { |route|
      route.path.spec.to_s.sub(
        /\(\.:format\)\z/,
        "",
      )
    }.reject { |path| path.include?(":") || path.include?("*") || path.match?(SKIP) }.uniq
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"

class PalmRouteContractTest < ActionDispatch::IntegrationTest
  PALM_HOST = ENV.fetch("PALM_SERVICE_URL", "palm.app.localhost")

  test "palm public host alias routes to app surface" do
    recognized = Rails.application.routes.recognize_path(
      "http://palm.jp.umaxica.app/",
      method: :get,
    )

    assert_equal "palm/app/roots", recognized[:controller]
    assert_equal "index", recognized[:action]
  end

  test "palm route contract" do
    recognized = Rails.application.routes.recognize_path(
      "http://#{PALM_HOST}/",
      method: :get,
    )

    assert_equal "palm/app/roots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{PALM_HOST}/health",
      method: :get,
    )

    assert_equal "palm/app/healths", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{PALM_HOST}/health/liveness",
      method: :get,
    )

    assert_equal "palm/app/health/livenesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{PALM_HOST}/health/readiness",
      method: :get,
    )

    assert_equal "palm/app/health/readinesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{PALM_HOST}/health/startup",
      method: :get,
    )

    assert_equal "palm/app/health/startups", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{PALM_HOST}/robots.txt",
      method: :get,
    )

    assert_equal "palm/app/robots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{PALM_HOST}/sitemap.xml",
      method: :get,
    )

    assert_equal "palm/app/sitemaps", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{PALM_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "palm/app/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{PALM_HOST}/api/v0/profile",
      method: :get,
    )

    assert_equal "palm/app/api/v0/profiles", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{PALM_HOST}/oauth/callback",
      method: :get,
    )

    assert_equal "palm/app/oauth/callbacks", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{PALM_HOST}/oauth/callback/ios",
      method: :get,
    )

    assert_equal "palm/app/oauth/callback/ios", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{PALM_HOST}/oauth/callback/android",
      method: :get,
    )

    assert_equal "palm/app/oauth/callback/android", recognized[:controller]
    assert_equal "index", recognized[:action]
  end
end

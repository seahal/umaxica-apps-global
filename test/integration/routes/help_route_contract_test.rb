# typed: false
# frozen_string_literal: true

require "test_helper"

class HelpRouteContractTest < ActionDispatch::IntegrationTest
  HELP_APP_HOST = ENV.fetch("HELP_SERVICE_URL", "help.app.localhost")
  HELP_COM_HOST = ENV.fetch("HELP_CORPORATE_URL", "help.com.localhost")
  HELP_ORG_HOST = ENV.fetch("HELP_STAFF_URL", "help.org.localhost")

  test "help app route contract" do
    recognized = Rails.application.routes.recognize_path(
      "http://#{HELP_APP_HOST}/",
      method: :get,
    )

    assert_equal "help/app/roots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{HELP_APP_HOST}/health",
      method: :get,
    )

    assert_equal "help/app/healths", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{HELP_APP_HOST}/health/liveness",
      method: :get,
    )

    assert_equal "help/app/health/livenesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{HELP_APP_HOST}/health/readiness",
      method: :get,
    )

    assert_equal "help/app/health/readinesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{HELP_APP_HOST}/health/startup",
      method: :get,
    )

    assert_equal "help/app/health/startups", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{HELP_APP_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "help/app/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{HELP_APP_HOST}/api/v0/entries",
      method: :get,
    )

    assert_equal "help/app/api/v0/entries", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{HELP_APP_HOST}/api/v0/entries/example",
      method: :get,
    )

    assert_equal "help/app/api/v0/entries", recognized[:controller]
    assert_equal "show", recognized[:action]
  end

  test "help com route contract" do
    recognized = Rails.application.routes.recognize_path(
      "http://#{HELP_COM_HOST}/",
      method: :get,
    )

    assert_equal "help/com/roots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{HELP_COM_HOST}/health",
      method: :get,
    )

    assert_equal "help/com/healths", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{HELP_COM_HOST}/health/liveness",
      method: :get,
    )

    assert_equal "help/com/health/livenesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{HELP_COM_HOST}/health/readiness",
      method: :get,
    )

    assert_equal "help/com/health/readinesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{HELP_COM_HOST}/health/startup",
      method: :get,
    )

    assert_equal "help/com/health/startups", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{HELP_COM_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "help/com/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{HELP_COM_HOST}/api/v0/entries",
      method: :get,
    )

    assert_equal "help/com/api/v0/entries", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{HELP_COM_HOST}/api/v0/entries/example",
      method: :get,
    )

    assert_equal "help/com/api/v0/entries", recognized[:controller]
    assert_equal "show", recognized[:action]
  end

  test "help org route contract" do
    recognized = Rails.application.routes.recognize_path(
      "http://#{HELP_ORG_HOST}/",
      method: :get,
    )

    assert_equal "help/org/roots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{HELP_ORG_HOST}/health",
      method: :get,
    )

    assert_equal "help/org/healths", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{HELP_ORG_HOST}/health/liveness",
      method: :get,
    )

    assert_equal "help/org/health/livenesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{HELP_ORG_HOST}/health/readiness",
      method: :get,
    )

    assert_equal "help/org/health/readinesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{HELP_ORG_HOST}/health/startup",
      method: :get,
    )

    assert_equal "help/org/health/startups", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{HELP_ORG_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "help/org/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{HELP_ORG_HOST}/api/v0/entries",
      method: :get,
    )

    assert_equal "help/org/api/v0/entries", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{HELP_ORG_HOST}/api/v0/entries/example",
      method: :get,
    )

    assert_equal "help/org/api/v0/entries", recognized[:controller]
    assert_equal "show", recognized[:action]
  end
end

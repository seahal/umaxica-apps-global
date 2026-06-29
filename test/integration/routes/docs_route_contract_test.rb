# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class DocsRouteContractTest < ActionDispatch::IntegrationTest
  DOCS_APP_HOST = ENV.fetch("PRIVATE_DOCS_SERVICE_URL")
  DOCS_COM_HOST = ENV.fetch("PRIVATE_DOCS_CORPORATE_URL")
  DOCS_ORG_HOST = ENV.fetch("PRIVATE_DOCS_STAFF_URL")
  PUBLIC_DOCS_HOSTS = {
    "docs.jp.umaxica.app" => "docs/app/roots",
    "docs.jp.umaxica.com" => "docs/com/roots",
    "docs.jp.umaxica.org" => "docs/org/roots",
  }.freeze

  test "docs public host aliases route to the matching surface" do
    PUBLIC_DOCS_HOSTS.each do |host, controller|
      recognized = Rails.application.routes.recognize_path("http://#{host}/", method: :get)

      assert_equal controller, recognized[:controller]
      assert_equal "index", recognized[:action]
    end
  end

  test "docs app route contract" do
    recognized = Rails.application.routes.recognize_path(
      "http://#{DOCS_APP_HOST}/",
      method: :get,
    )

    assert_equal "docs/app/roots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{DOCS_APP_HOST}/health",
      method: :get,
    )

    assert_equal "docs/app/healths", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{DOCS_APP_HOST}/health/liveness",
      method: :get,
    )

    assert_equal "docs/app/health/livenesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{DOCS_APP_HOST}/health/readiness",
      method: :get,
    )

    assert_equal "docs/app/health/readinesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{DOCS_APP_HOST}/health/startup",
      method: :get,
    )

    assert_equal "docs/app/health/startups", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{DOCS_APP_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "docs/app/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{DOCS_APP_HOST}/api/v0/entries",
      method: :get,
    )

    assert_equal "docs/app/api/v0/entries", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{DOCS_APP_HOST}/api/v0/entries/example",
      method: :get,
    )

    assert_equal "docs/app/api/v0/entries", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{DOCS_APP_HOST}/api/v0/entries/example/revisions",
      method: :get,
    )

    assert_equal "docs/app/api/v0/entries/revisions", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{DOCS_APP_HOST}/api/v0/entries/example/revisions/rev-1",
      method: :get,
    )

    assert_equal "docs/app/api/v0/entries/revisions", recognized[:controller]
    assert_equal "show", recognized[:action]
  end

  test "docs com route contract" do
    recognized = Rails.application.routes.recognize_path(
      "http://#{DOCS_COM_HOST}/",
      method: :get,
    )

    assert_equal "docs/com/roots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{DOCS_COM_HOST}/health",
      method: :get,
    )

    assert_equal "docs/com/healths", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{DOCS_COM_HOST}/health/liveness",
      method: :get,
    )

    assert_equal "docs/com/health/livenesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{DOCS_COM_HOST}/health/readiness",
      method: :get,
    )

    assert_equal "docs/com/health/readinesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{DOCS_COM_HOST}/health/startup",
      method: :get,
    )

    assert_equal "docs/com/health/startups", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{DOCS_COM_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "docs/com/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{DOCS_COM_HOST}/api/v0/entries",
      method: :get,
    )

    assert_equal "docs/com/api/v0/entries", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{DOCS_COM_HOST}/api/v0/entries/example",
      method: :get,
    )

    assert_equal "docs/com/api/v0/entries", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{DOCS_COM_HOST}/api/v0/entries/example/revisions",
      method: :get,
    )

    assert_equal "docs/com/api/v0/entries/revisions", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{DOCS_COM_HOST}/api/v0/entries/example/revisions/rev-1",
      method: :get,
    )

    assert_equal "docs/com/api/v0/entries/revisions", recognized[:controller]
    assert_equal "show", recognized[:action]
  end

  test "docs org route contract" do
    recognized = Rails.application.routes.recognize_path(
      "http://#{DOCS_ORG_HOST}/",
      method: :get,
    )

    assert_equal "docs/org/roots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{DOCS_ORG_HOST}/health",
      method: :get,
    )

    assert_equal "docs/org/healths", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{DOCS_ORG_HOST}/health/liveness",
      method: :get,
    )

    assert_equal "docs/org/health/livenesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{DOCS_ORG_HOST}/health/readiness",
      method: :get,
    )

    assert_equal "docs/org/health/readinesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{DOCS_ORG_HOST}/health/startup",
      method: :get,
    )

    assert_equal "docs/org/health/startups", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{DOCS_ORG_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "docs/org/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{DOCS_ORG_HOST}/api/v0/entries",
      method: :get,
    )

    assert_equal "docs/org/api/v0/entries", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{DOCS_ORG_HOST}/api/v0/entries/example",
      method: :get,
    )

    assert_equal "docs/org/api/v0/entries", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{DOCS_ORG_HOST}/api/v0/entries/example/revisions",
      method: :get,
    )

    assert_equal "docs/org/api/v0/entries/revisions", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{DOCS_ORG_HOST}/api/v0/entries/example/revisions/rev-1",
      method: :get,
    )

    assert_equal "docs/org/api/v0/entries/revisions", recognized[:controller]
    assert_equal "show", recognized[:action]
  end
end

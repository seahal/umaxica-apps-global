# typed: false
# frozen_string_literal: true

require "test_helper"

class NewsRouteContractTest < ActionDispatch::IntegrationTest
  NEWS_APP_HOST = ENV.fetch("NEWS_SERVICE_URL", "news.app.localhost")
  NEWS_COM_HOST = ENV.fetch("NEWS_CORPORATE_URL", "news.com.localhost")
  NEWS_ORG_HOST = ENV.fetch("NEWS_STAFF_URL", "news.org.localhost")

  test "news app route contract" do
    recognized = Rails.application.routes.recognize_path(
      "http://#{NEWS_APP_HOST}/",
      method: :get,
    )

    assert_equal "news/app/roots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{NEWS_APP_HOST}/health",
      method: :get,
    )

    assert_equal "news/app/healths", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{NEWS_APP_HOST}/health/liveness",
      method: :get,
    )

    assert_equal "news/app/health/livenesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{NEWS_APP_HOST}/health/readiness",
      method: :get,
    )

    assert_equal "news/app/health/readinesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{NEWS_APP_HOST}/health/startup",
      method: :get,
    )

    assert_equal "news/app/health/startups", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{NEWS_APP_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "news/app/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{NEWS_APP_HOST}/api/v0/entries",
      method: :get,
    )

    assert_equal "news/app/api/v0/entries", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{NEWS_APP_HOST}/api/v0/entries/example",
      method: :get,
    )

    assert_equal "news/app/api/v0/entries", recognized[:controller]
    assert_equal "show", recognized[:action]
  end

  test "news com route contract" do
    recognized = Rails.application.routes.recognize_path(
      "http://#{NEWS_COM_HOST}/",
      method: :get,
    )

    assert_equal "news/com/roots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{NEWS_COM_HOST}/health",
      method: :get,
    )

    assert_equal "news/com/healths", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{NEWS_COM_HOST}/health/liveness",
      method: :get,
    )

    assert_equal "news/com/health/livenesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{NEWS_COM_HOST}/health/readiness",
      method: :get,
    )

    assert_equal "news/com/health/readinesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{NEWS_COM_HOST}/health/startup",
      method: :get,
    )

    assert_equal "news/com/health/startups", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{NEWS_COM_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "news/com/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{NEWS_COM_HOST}/api/v0/entries",
      method: :get,
    )

    assert_equal "news/com/api/v0/entries", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{NEWS_COM_HOST}/api/v0/entries/example",
      method: :get,
    )

    assert_equal "news/com/api/v0/entries", recognized[:controller]
    assert_equal "show", recognized[:action]
  end

  test "news org route contract" do
    recognized = Rails.application.routes.recognize_path(
      "http://#{NEWS_ORG_HOST}/",
      method: :get,
    )

    assert_equal "news/org/roots", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{NEWS_ORG_HOST}/health",
      method: :get,
    )

    assert_equal "news/org/healths", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{NEWS_ORG_HOST}/health/liveness",
      method: :get,
    )

    assert_equal "news/org/health/livenesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{NEWS_ORG_HOST}/health/readiness",
      method: :get,
    )

    assert_equal "news/org/health/readinesses", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{NEWS_ORG_HOST}/health/startup",
      method: :get,
    )

    assert_equal "news/org/health/startups", recognized[:controller]
    assert_equal "show", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{NEWS_ORG_HOST}/csp-violation-report",
      method: :post,
    )

    assert_equal "news/org/csp_violation_reports", recognized[:controller]
    assert_equal "create", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{NEWS_ORG_HOST}/api/v0/entries",
      method: :get,
    )

    assert_equal "news/org/api/v0/entries", recognized[:controller]
    assert_equal "index", recognized[:action]

    recognized = Rails.application.routes.recognize_path(
      "http://#{NEWS_ORG_HOST}/api/v0/entries/example",
      method: :get,
    )

    assert_equal "news/org/api/v0/entries", recognized[:controller]
    assert_equal "show", recognized[:action]
  end
end

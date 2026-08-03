# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class NewsRouteContractTest < ActionDispatch::IntegrationTest
  NEWS_APP_HOST = ENV.fetch("PRIVATE_NEWS_SERVICE_URL")
  NEWS_COM_HOST = ENV.fetch("PRIVATE_NEWS_CORPORATE_URL")
  NEWS_ORG_HOST = ENV.fetch("PRIVATE_NEWS_STAFF_URL")
  PUBLIC_NEWS_HOSTS = {
    "news.jp.umaxica.app" => "news/app/roots",
    "news.jp.umaxica.com" => "news/com/roots",
    "news.jp.umaxica.org" => "news/org/roots",
  }.freeze
  PRIVATE_ORIGIN_HOSTS = {
    "news.app.localhost" => "news/app/roots",
    "news.com.localhost" => "news/com/roots",
    "news.org.localhost" => "news/org/roots",
  }.freeze

  test "news private origin hosts route to the matching surface" do
    PRIVATE_ORIGIN_HOSTS.each do |host, controller|
      recognized = Rails.application.routes.recognize_path("http://#{host}/", method: :get)

      assert_equal controller, recognized[:controller]
      assert_equal "index", recognized[:action]
    end
  end

  test "news public host aliases route to the matching surface" do
    PUBLIC_NEWS_HOSTS.each do |host, controller|
      recognized = Rails.application.routes.recognize_path("http://#{host}/", method: :get)

      assert_equal controller, recognized[:controller]
      assert_equal "index", recognized[:action]
    end
  end

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

    # The nested revision endpoints were removed: revisions are an internal
    # lifecycle concept, never a public contract.
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{NEWS_APP_HOST}/api/v0/entries/example/revisions",
        method: :get,
      )
    end
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

    # The nested revision endpoints were removed: revisions are an internal
    # lifecycle concept, never a public contract.
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{NEWS_COM_HOST}/api/v0/entries/example/revisions",
        method: :get,
      )
    end
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

    # The nested revision endpoints were removed: revisions are an internal
    # lifecycle concept, never a public contract.
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{NEWS_ORG_HOST}/api/v0/entries/example/revisions",
        method: :get,
      )
    end
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# Contract for the deployment identifier endpoint. Every FQDN this application
# answers must expose GET/HEAD /revision with the same headers and JSON shape,
# and the value must come only from Rails.application.revision.
class RevisionEndpointTest < ActionDispatch::IntegrationTest
  REVISION = "0123456789abcdef0123456789abcdef01234567"

  SURFACES = [
    { host: ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost"), controller: "auth/app/revisions" },
    { host: ENV.fetch("PRIVATE_AUTH_CORPORATE_URL", "sign.com.localhost"), controller: "auth/com/revisions" },
    { host: ENV.fetch("PRIVATE_AUTH_STAFF_URL", "sign.org.localhost"), controller: "auth/org/revisions" },
    { host: ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"), controller: "base/app/revisions" },
    { host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"), controller: "base/com/revisions" },
    { host: ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"), controller: "base/org/revisions" },
    { host: ENV.fetch("PRIVATE_BASE_NETWORK_URL", "base.net.localhost"), controller: "base/net/revisions" },
    { host: ENV.fetch("PRIVATE_BASE_DEVELOPER_URL", "base.dev.localhost"), controller: "base/dev/revisions" },
    { host: ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost"), controller: "core/app/revisions" },
    { host: ENV.fetch("PUBLIC_CORE_CORPORATE_URL", "core.com.localhost"), controller: "core/com/revisions" },
    { host: ENV.fetch("PUBLIC_CORE_STAFF_URL", "core.org.localhost"), controller: "core/org/revisions" },
    { host: ENV.fetch("PRIVATE_CORE_NETWORK_URL", "core.net.localhost"), controller: "core/net/revisions" },
    { host: ENV.fetch("PRIVATE_CORE_DEVELOPER_URL", "core.dev.localhost"), controller: "core/dev/revisions" },
    { host: ENV.fetch("PUBLIC_SIDE_SERVICE_URL", "side.app.localhost"), controller: "side/app/revisions" },
    { host: ENV.fetch("PUBLIC_SIDE_CORPORATE_URL", "side.com.localhost"), controller: "side/com/revisions" },
    { host: ENV.fetch("PUBLIC_SIDE_STAFF_URL", "side.org.localhost"), controller: "side/org/revisions" },
    { host: ENV.fetch("PUBLIC_PALM_SERVICE_URL"), controller: "palm/app/revisions" },
    { host: ENV.fetch("PRIVATE_HELP_SERVICE_URL"), controller: "help/app/revisions" },
    { host: ENV.fetch("PRIVATE_HELP_CORPORATE_URL"), controller: "help/com/revisions" },
    { host: ENV.fetch("PRIVATE_HELP_STAFF_URL"), controller: "help/org/revisions" },
    { host: ENV.fetch("PRIVATE_DOCS_SERVICE_URL"), controller: "docs/app/revisions" },
    { host: ENV.fetch("PRIVATE_DOCS_CORPORATE_URL"), controller: "docs/com/revisions" },
    { host: ENV.fetch("PRIVATE_DOCS_STAFF_URL"), controller: "docs/org/revisions" },
    { host: ENV.fetch("PRIVATE_NEWS_SERVICE_URL"), controller: "news/app/revisions" },
    { host: ENV.fetch("PRIVATE_NEWS_CORPORATE_URL"), controller: "news/com/revisions" },
    { host: ENV.fetch("PRIVATE_NEWS_STAFF_URL"), controller: "news/org/revisions" },
    { host: "info.app.localhost", controller: "info/app/revisions" },
    { host: "info.com.localhost", controller: "info/com/revisions" },
    { host: "info.org.localhost", controller: "info/org/revisions" },
  ].freeze

  test "every surface host routes /revision to its own revisions controller" do
    SURFACES.each do |surface|
      %i(get head).each do |method|
        recognized = Rails.application.routes.recognize_path("http://#{surface[:host]}/revision", method: method)

        assert_equal surface[:controller], recognized[:controller]
        assert_equal "show", recognized[:action]
      end
    end
  end

  test "every revisions controller is bare and uses the shared rendering concern" do
    SURFACES.map { |surface| surface[:controller] }.uniq.each do |controller|
      controller_class = "#{controller}_controller".camelize.constantize

      assert_includes controller_class.ancestors, ::ApplicationRevisionRendering
      assert_equal :bare, controller_class.const_get(:AUTHENTICATION_MODE, false)
    end
  end

  test "every surface host answers the same revision contract" do
    SURFACES.each do |surface|
      host! surface[:host]

      Rails.application.stub(:revision, REVISION) do
        get "/revision"
      end

      assert_response :success, "GET /revision failed on #{surface[:host]}"
      assert_equal "application/json; charset=utf-8", response.headers["Content-Type"]
      assert_equal "no-store", response.headers["Cache-Control"]
      assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
      assert_equal({ "revision" => REVISION }, response.parsed_body)
      assert_not_predicate response, :redirect?
    end
  end

  test "a missing revision is a successful null response, not an error" do
    host! ENV.fetch("PUBLIC_SIDE_SERVICE_URL", "side.app.localhost")

    Rails.application.stub(:revision, nil) do
      get "/revision"
    end

    assert_response :success
    assert_equal({ "revision" => nil }, response.parsed_body)
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
  end

  test "revision is passed through verbatim without truncation" do
    host! ENV.fetch("PUBLIC_SIDE_SERVICE_URL", "side.app.localhost")
    verbatim = "v2026.08.11+#{REVISION}"

    Rails.application.stub(:revision, verbatim) do
      get "/revision"
    end

    assert_equal({ "revision" => verbatim }, response.parsed_body)
  end

  test "revision never renders html or an authentication redirect" do
    host! ENV.fetch("PUBLIC_SIDE_SERVICE_URL", "side.app.localhost")

    [nil, "text/html", "*/*"].each do |accept|
      headers = accept ? { "Accept" => accept } : {}

      Rails.application.stub(:revision, REVISION) do
        get "/revision", headers: headers
      end

      assert_response :success
      assert_equal "application/json", response.media_type
      assert_not_predicate response, :redirect?
      assert_not_includes response.body, "<html"
    end
  end

  test "revision needs no database query" do
    host! ENV.fetch("PUBLIC_SIDE_SERVICE_URL", "side.app.localhost")

    assert_no_queries do
      Rails.application.stub(:revision, REVISION) do
        get "/revision"
      end
    end

    assert_response :success
  end

  test "revision response leaks no internal detail" do
    host! ENV.fetch("PUBLIC_SIDE_SERVICE_URL", "side.app.localhost")

    Rails.application.stub(:revision, REVISION) do
      get "/revision"
    end

    forbidden = [
      Rails.root.to_s,
      Rails.application.class.name,
      ENV.fetch("PUBLIC_SIDE_SERVICE_URL", "side.app.localhost"),
      "secret_key_base",
      "REVISION",
      "git",
    ]

    forbidden.each { |value| assert_not_includes response.body, value }
    assert_no_match(%r{\.rb:\d+|backtrace|Traceback}, response.body)
    assert_equal(%w(revision), response.parsed_body.keys)
  end

  test "head requests satisfy the same contract with an empty body" do
    host! ENV.fetch("PUBLIC_SIDE_SERVICE_URL", "side.app.localhost")

    Rails.application.stub(:revision, REVISION) do
      head "/revision"
    end

    assert_response :success
    assert_equal "application/json; charset=utf-8", response.headers["Content-Type"]
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
    assert_empty response.body
  end

  test "unknown hosts gain no revision route" do
    ["revision.example.test", "wrong.example.test"].each do |host|
      assert_raises(ActionController::RoutingError, "#{host} must not be routable") do
        Rails.application.routes.recognize_path("http://#{host}/revision", method: :get)
      end
    end
  end
end

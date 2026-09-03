# typed: false
# frozen_string_literal: true

require "test_helper"

# The final wire contract for the health and revision endpoints, exercised end to end on two
# surfaces (base/app and base/com).
#
# Two endpoint families:
#
#   Text (text/plain; charset=utf-8, Cache-Control: no-store, no redirect, no auth):
#     GET /health            -> aggregate block: status, startup, liveness, readiness
#     GET /health/startup    -> "ok\n" / HTTP 503
#     GET /health/liveness   -> "ok\n" / HTTP 503
#     GET /health/readiness  -> "ok\n" / HTTP 503
#     GET /revision          -> "<revision>\n"  (nil revision -> "\n")
#
#   Machine JSON (application/json, Cache-Control: no-store, 406 on a non-JSON Accept):
#     GET /api/v0/health.json   -> {"status":"pass|warn|fail","checks":{startup,liveness,readiness}}
#     GET /api/v0/revision.json -> {"revision":"<sha>"}  (nil revision -> {"revision":null})
class HealthRevisionContractTest < ActionDispatch::IntegrationTest
  REVISION = "0123456789abcdef0123456789abcdef01234567"

  APP_HOST = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
  COM_HOST = ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost")

  SURFACES = {
    APP_HOST => Health::Profiles::App,
    COM_HOST => Health::Profiles::Com,
  }.freeze

  PROBES = %w(startup liveness readiness).freeze

  JSON_BRACE = /\A\s*[{\[]/
  HTML_MARKER = /<!doctype|<html/i

  # ----------------------------------------------------------------------------------------------
  # Text: probes
  # ----------------------------------------------------------------------------------------------

  test "each text probe returns exactly \"ok\\n\" as text/plain, never JSON or HTML, no redirect" do
    SURFACES.each_key do |host|
      host! host

      PROBES.each do |probe|
        stub_healthy do
          get "/health/#{probe}"
        end

        assert_response :success
        assert_not_predicate response, :redirect?
        assert_equal "text/plain", response.media_type, "#{host} /health/#{probe} media type"
        assert_not_equal "application/json", response.media_type
        assert_not_equal "text/html", response.media_type
        assert_equal "ok\n", response.body
        assert_no_match JSON_BRACE, response.body
        assert_no_match HTML_MARKER, response.body
        assert_equal "no-store", response.headers["Cache-Control"]
      end
    end
  end

  test "text probes stay text/plain under a JSON, HTML, or wildcard Accept" do
    host! APP_HOST

    ["application/json", "text/html", "*/*"].each do |accept|
      stub_healthy do
        get "/health/liveness", headers: { "Accept" => accept }
      end

      assert_response :success
      assert_equal "text/plain", response.media_type, "Accept: #{accept}"
      assert_equal "ok\n", response.body
    end
  end

  # ----------------------------------------------------------------------------------------------
  # Text: aggregate /health
  # ----------------------------------------------------------------------------------------------

  test "GET /health is the four-line text aggregate in the fixed order" do
    SURFACES.each do |host, profile|
      host! host

      Health::SnapshotCheck.stub(:call, healthy_snapshot(profile)) do
        get "/health"
      end

      assert_response :success
      assert_not_predicate response, :redirect?
      assert_equal "text/plain", response.media_type
      assert_not_equal "application/json", response.media_type
      assert_not_equal "text/html", response.media_type
      assert_equal "status: ok\nstartup: ok\nliveness: ok\nreadiness: ok\n", response.body
      assert_no_match JSON_BRACE, response.body
      assert_no_match HTML_MARKER, response.body
      assert_equal "no-store", response.headers["Cache-Control"]
    end
  end

  # ----------------------------------------------------------------------------------------------
  # Text: /revision
  # ----------------------------------------------------------------------------------------------

  test "GET /revision is \"<revision>\\n\" as text/plain with no-store and X-Robots-Tag" do
    SURFACES.each_key do |host|
      host! host

      Rails.application.stub(:revision, REVISION) do
        get "/revision"
      end

      assert_response :success
      assert_not_predicate response, :redirect?
      assert_equal "text/plain", response.media_type
      assert_not_equal "application/json", response.media_type
      assert_not_equal "text/html", response.media_type
      assert_equal "#{REVISION}\n", response.body
      assert_no_match JSON_BRACE, response.body
      assert_equal "no-store", response.headers["Cache-Control"]
      assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
    end
  end

  test "GET /revision with a nil application revision is \"\\n\", a normal 200" do
    host! APP_HOST

    Rails.application.stub(:revision, nil) do
      get "/revision"
    end

    assert_response :success
    assert_equal "\n", response.body
    assert_equal "text/plain", response.media_type
  end

  test "GET /revision stays text/plain under a JSON or HTML Accept" do
    host! APP_HOST

    ["application/json", "text/html", "*/*"].each do |accept|
      Rails.application.stub(:revision, REVISION) do
        get "/revision", headers: { "Accept" => accept }
      end

      assert_response :success
      assert_equal "text/plain", response.media_type, "Accept: #{accept}"
      assert_equal "#{REVISION}\n", response.body
    end
  end

  test "GET /revision issues no database query" do
    host! APP_HOST

    assert_no_queries do
      Rails.application.stub(:revision, REVISION) do
        get "/revision"
      end
    end

    assert_response :success
  end

  test "HEAD /revision matches GET on status, content type, and cache, with an empty body" do
    host! APP_HOST

    Rails.application.stub(:revision, REVISION) do
      get "/revision"
    end
    get_status = response.status
    get_content_type = response.headers["Content-Type"]
    get_cache = response.headers["Cache-Control"]

    Rails.application.stub(:revision, REVISION) do
      head "/revision"
    end

    assert_equal get_status, response.status
    assert_equal get_content_type, response.headers["Content-Type"]
    assert_equal get_cache, response.headers["Cache-Control"]
    assert_empty response.body
  end

  # ----------------------------------------------------------------------------------------------
  # Machine JSON: /api/v0/revision.json
  # ----------------------------------------------------------------------------------------------

  test "GET /api/v0/revision.json is {\"revision\":\"<sha>\"} as application/json, never text or HTML" do
    SURFACES.each_key do |host|
      host! host

      Rails.application.stub(:revision, REVISION) do
        get "/api/v0/revision.json", headers: { "Accept" => "application/json" }
      end

      assert_response :success
      assert_not_predicate response, :redirect?
      assert_equal "application/json", response.media_type
      assert_not_equal "text/plain", response.media_type
      assert_not_equal "text/html", response.media_type
      assert_no_match HTML_MARKER, response.body
      assert_equal({ "revision" => REVISION }, response.parsed_body)
      assert_equal %w(revision), response.parsed_body.keys
      assert_equal "no-store", response.headers["Cache-Control"]
    end
  end

  test "GET /api/v0/revision.json with a nil application revision is {\"revision\":null}" do
    host! APP_HOST

    Rails.application.stub(:revision, nil) do
      get "/api/v0/revision.json", headers: { "Accept" => "application/json" }
    end

    assert_response :success
    assert_equal({ "revision" => nil }, response.parsed_body)
  end

  test "GET /api/v0/revision.json returns 406 for a non-JSON Accept, not a text or HTML fallback" do
    host! APP_HOST

    ["text/html", "text/plain"].each do |accept|
      Rails.application.stub(:revision, REVISION) do
        get "/api/v0/revision.json", headers: { "Accept" => accept }
      end

      assert_response :not_acceptable, "Accept: #{accept}"
      assert_empty response.body
      assert_equal "no-store", response.headers["Cache-Control"]
    end
  end

  test "GET /api/v0/revision.json issues no database query" do
    host! APP_HOST

    assert_no_queries do
      Rails.application.stub(:revision, REVISION) do
        get "/api/v0/revision.json", headers: { "Accept" => "application/json" }
      end
    end

    assert_response :success
  end

  # ----------------------------------------------------------------------------------------------
  # Machine JSON: /api/v0/health.json
  # ----------------------------------------------------------------------------------------------

  test "GET /api/v0/health.json is the pass/warn/fail schema as application/json, never text or HTML" do
    SURFACES.each_key do |host|
      host! host

      stub_healthy do
        get "/api/v0/health.json", headers: { "Accept" => "application/json" }
      end

      assert_response :success
      assert_not_predicate response, :redirect?
      assert_equal "application/json", response.media_type
      assert_not_equal "text/plain", response.media_type
      assert_not_equal "text/html", response.media_type
      assert_no_match HTML_MARKER, response.body

      body = response.parsed_body

      assert_equal %w(checks status), body.keys.sort
      assert_equal %w(liveness readiness startup), body.fetch("checks").keys.sort
      assert_includes %w(pass warn fail), body.fetch("status")

      body.fetch("checks").each_value do |check|
        assert_equal %w(status), check.keys
        assert_includes %w(pass warn fail), check.fetch("status")
      end

      assert_equal "pass", body.fetch("status")
      assert_equal "no-store", response.headers["Cache-Control"]
    end
  end

  test "GET /api/v0/health.json returns 406 for a non-JSON Accept, not a text or HTML fallback" do
    host! APP_HOST

    ["text/html", "text/plain"].each do |accept|
      get "/api/v0/health.json", headers: { "Accept" => accept }

      assert_response :not_acceptable, "Accept: #{accept}"
      assert_empty response.body
      assert_equal "no-store", response.headers["Cache-Control"]
    end
  end

  test "GET /api/v0/health.json body leaks no internal detail" do
    host! APP_HOST

    stub_healthy do
      get "/api/v0/health.json", headers: { "Accept" => "application/json" }
    end

    assert_response :success

    forbidden = [
      Rails.root.to_s,
      APP_HOST,
      "secret_key_base",
      "git",
      "AppRpRecord",
      "PG::",
      "StandardError",
    ]

    forbidden.each { |value| assert_not_includes response.body, value }
    assert_no_match(/\.rb:\d+|backtrace|Traceback/, response.body)
  end

  # ----------------------------------------------------------------------------------------------
  # Failure path: a readiness outage fails readiness and the machine aggregate, never liveness
  # ----------------------------------------------------------------------------------------------

  test "a readiness outage is 503 on readiness and the machine aggregate, but liveness still passes" do
    host! APP_HOST
    profile = Health::Profiles::App
    unready = Health::CheckResult.new(check: :readiness, status: :unready, surface: profile.surface_label)

    Health::ReadinessCheck.stub(:call, unready) do
      get "/api/v0/health.json", headers: { "Accept" => "application/json" }
    end

    assert_response :service_unavailable
    body = response.parsed_body

    assert_equal "fail", body.fetch("status")
    assert_equal "fail", body.dig("checks", "readiness", "status")
    assert_equal "pass", body.dig("checks", "liveness", "status")
    assert_equal "pass", body.dig("checks", "startup", "status")
    assert_equal "no-store", response.headers["Cache-Control"]

    Health::ReadinessCheck.stub(:call, unready) do
      get "/health/readiness"
    end

    assert_response :service_unavailable
    assert_equal "text/plain", response.media_type
    assert_equal "unavailable\n", response.body
    assert_equal "no-store", response.headers["Cache-Control"]

    get "/health/liveness"

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_equal "ok\n", response.body
  end

  private

  def ok_result(check, profile)
    Health::CheckResult.new(check: check, status: :ok, surface: profile.surface_label)
  end

  def healthy_snapshot(profile)
    Health::CheckResult.new(
      check: :health,
      status: :ok,
      surface: profile.surface_label,
      dependencies: {
        "liveness" => ok_result(:liveness, profile).as_public_json,
        "readiness" => ok_result(:readiness, profile).as_public_json,
        "startup" => ok_result(:startup, profile).as_public_json,
      },
    )
  end

  # Deterministic "everything healthy" for the probe and machine-aggregate assertions: the probe
  # semantics themselves are covered by test/services/health_test.rb, so these tests pin only the
  # wire contract. The surface label on a CheckResult is not part of any wire body here, so a
  # single profile is enough to stand every probe up.
  def stub_healthy(&)
    profile = Health::Profiles::App
    Health::LivenessCheck.stub(:call, ok_result(:liveness, profile)) do
      Health::ReadinessCheck.stub(:call, ok_result(:readiness, profile)) do
        Health::StartupCheck.stub(:call, ok_result(:startup, profile), &)
      end
    end
  end
end

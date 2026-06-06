# typed: false
# frozen_string_literal: true

require "test_helper"

class HealthEndpointsTest < ActionDispatch::IntegrationTest
  SURFACES = [
    {
      host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
      controller: "acme/app/healths",
      live_controller: "acme/app/health/lives",
      ready_controller: "acme/app/health/readies",
      startup_controller: "acme/app/health/startups",
      profile: Health::Profiles::App,
    },
    {
      host: ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost"),
      controller: "acme/com/healths",
      live_controller: "acme/com/health/lives",
      ready_controller: "acme/com/health/readies",
      startup_controller: "acme/com/health/startups",
      profile: Health::Profiles::Com,
    },
    {
      host: ENV.fetch("ACME_STAFF_URL", "www.org.localhost"),
      controller: "acme/org/healths",
      live_controller: "acme/org/health/lives",
      ready_controller: "acme/org/health/readies",
      startup_controller: "acme/org/health/startups",
      profile: Health::Profiles::Org,
    },
    {
      host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
      controller: "sign/app/healths",
      live_controller: "sign/app/health/lives",
      ready_controller: "sign/app/health/readies",
      startup_controller: "sign/app/health/startups",
      profile: Health::Profiles::SignApp,
    },
    {
      host: ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost"),
      controller: "sign/com/healths",
      live_controller: "sign/com/health/lives",
      ready_controller: "sign/com/health/readies",
      startup_controller: "sign/com/health/startups",
      profile: Health::Profiles::SignCom,
    },
    {
      host: ENV.fetch("SIGN_STAFF_URL", "id.org.localhost"),
      controller: "sign/org/healths",
      live_controller: "sign/org/health/lives",
      ready_controller: "sign/org/health/readies",
      startup_controller: "sign/org/health/startups",
      profile: Health::Profiles::SignOrg,
    },
    {
      host: ENV.fetch("CORE_SERVICE_URL", "core.app.localhost"),
      controller: "core/app/healths",
      live_controller: "core/app/health/lives",
      ready_controller: "core/app/health/readies",
      startup_controller: "core/app/health/startups",
      profile: Health::Profiles::App,
    },
    {
      host: ENV.fetch("CORE_CORPORATE_URL", "core.com.localhost"),
      controller: "core/com/healths",
      live_controller: "core/com/health/lives",
      ready_controller: "core/com/health/readies",
      startup_controller: "core/com/health/startups",
      profile: Health::Profiles::Com,
    },
    {
      host: ENV.fetch("CORE_STAFF_URL", "core.org.localhost"),
      controller: "core/org/healths",
      live_controller: "core/org/health/lives",
      ready_controller: "core/org/health/readies",
      startup_controller: "core/org/health/startups",
      profile: Health::Profiles::Org,
    },
  ].freeze

  test "surface routes resolve to concrete local controllers with exact profiles" do
    SURFACES.each do |surface|
      assert_health_route(surface[:host], "/health", surface[:controller])
      assert_health_route(surface[:host], "/health/live", surface[:live_controller])
      assert_health_route(surface[:host], "/health/ready", surface[:ready_controller])
      assert_health_route(surface[:host], "/health/startup", surface[:startup_controller])

      [
        surface[:controller],
        surface[:live_controller],
        surface[:ready_controller],
        surface[:startup_controller],
      ].each do |controller|
        controller_class = "#{controller}_controller".camelize.constantize

        assert_same surface[:profile], controller_class.const_get(:HEALTH_PROFILE, false)
      end
    end
  end

  test "health html is server rendered snapshot without javascript polling" do
    host! ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")

    get "/health"

    assert_response :success
    assert_includes response.media_type, "text/html"
    assert_includes response.body, "Health Snapshot"
    assert_includes response.body, "point-in-time health snapshot"
    assert_includes response.body, "Generated at"
    assert_no_match(/fetch\s*\(/i, response.body)
    assert_no_match(/setInterval|setTimeout|EventSource|WebSocket/i, response.body)
  end

  test "json probes render json regardless of accept header and html suffix" do
    host! ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")

    %w(live ready startup).each do |probe|
      [nil, "text/html", "*/*"].each do |accept|
        headers = accept ? { "Accept" => accept } : {}

        get "/health/#{probe}", headers: headers

        assert_includes [200, 503], response.status
        assert_equal "application/json", response.media_type
        assert_equal probe, response.parsed_body["probe"]
      end
    end

    get "/health/ready.html", headers: { "Accept" => "text/html" }

    assert_equal "application/json", response.media_type
    assert_equal "ready", response.parsed_body["probe"]

    get "/health/startup.html", headers: { "Accept" => "text/html" }

    assert_equal "application/json", response.media_type
    assert_equal "startup", response.parsed_body["probe"]
  end

  test "liveness remains dependency free" do
    host! ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")

    Health::Readiness.stub(:call, ->(_profile:) { raise RuntimeError, "readiness loaded" }) do
      ActiveRecord::Base.stub(:connection, -> { raise RuntimeError, "database touched" }) do
        if defined?(REDIS_CLIENT)
          REDIS_CLIENT.stub(:ping, -> { raise RuntimeError, "redis touched" }) do
            get "/health/live"
          end
        else
          get "/health/live"
        end
      end
    end

    assert_response :success
    assert_equal "ok", response.parsed_body["status"]
    assert_empty response.parsed_body["checks"]
  end

  test "startup remains dependency light" do
    host! ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")

    Health::Checks::Database.stub(:new, ->(*) { raise RuntimeError, "database check built" }) do
      get "/health/startup"
    end

    assert_response :success
    assert_equal ["boot"], response.parsed_body["checks"].pluck("kind")
  end

  test "app readiness ignores org-only dependencies" do
    host! ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")

    assert_readiness_does_not_build(OrgTicketRecord)
  end

  test "sign readiness ignores acme-only dependencies" do
    host! ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")

    assert_readiness_does_not_build(AppRpRecord)
  end

  test "new database base classes do not affect existing surfaces by default" do
    host! ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")

    new_record_base = Class.new(ApplicationRecord)

    assert_readiness_does_not_build(new_record_base)
  end

  test "status codes come from report status" do
    host! ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")

    assert_probe_status(:ok, :success)
    assert_probe_status(:degraded_acceptable, :success)
    assert_probe_status(:unready, :service_unavailable)
  end

  test "public responses omit topology and exception details" do
    host! ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")
    report = Health::Report.aggregate(
      profile: Health::Profiles::SignApp,
      probe: :ready,
      checks: [Health::Check::Result.new(kind: :database, status: :unready, message: "Dependency unavailable")],
    )

    Health::Readiness.stub(:call, report) do
      get "/health/ready"
    end

    forbidden = %w(
      AppPrincipalRecord app_principal app_principal_replica writing reading localhost
      StandardError PG::ConnectionBad Mysql2 Redis REDIS_CLIENT
    )

    forbidden.each do |value|
      assert_not_includes response.body, value
    end

    get "/health/ready?debug=1", headers: { "Accept" => "text/html" }

    forbidden.each do |value|
      assert_not_includes response.body, value
    end
  end

  test "wrong host is not routed to public health" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://wrong.example.test/health", method: :get)
    end
  end

  test "missing and inherited health profiles fail loudly" do
    missing =
      Class.new(::ApplicationController) do
        include Health::Controller
      end
    inherited_parent =
      Class.new(::ApplicationController) do
        include Health::Controller
      end
    inherited_parent.const_set(:HEALTH_PROFILE, Health::Profiles::App)
    inherited_child = Class.new(inherited_parent)

    assert_raises(Health::MissingProfileError) { missing.new.send(:health_profile) }
    assert_raises(Health::MissingProfileError) { inherited_child.new.send(:health_profile) }
  end

  private

  def assert_health_route(host, path, controller)
    recognized = Rails.application.routes.recognize_path("http://#{host}#{path}", method: :get)

    assert_equal controller, recognized[:controller]
    assert_equal "show", recognized[:action]
  end

  def assert_probe_status(status, expected_response)
    report = Health::Report.new(profile: Health::Profiles::SignApp, probe: :ready, status: status, checks: [])

    Health::Readiness.stub(:call, report) do
      get("/health/ready")
    end

    assert_response expected_response
  end

  def assert_readiness_does_not_build(forbidden_record_class)
    Health::Checks::Database.stub(
      :new,
      lambda { |record_class:, **_options|
        raise RuntimeError, "unexpected dependency" if record_class == forbidden_record_class

        Struct.new(:result) do
          def call = result
        end.new(Health::Check::Result.new(kind: :database, status: :ok))
      },
    ) do
      get("/health/ready")
    end

    assert_response :success
  end
end

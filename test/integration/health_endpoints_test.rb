# typed: false
# frozen_string_literal: true

require "test_helper"

class HealthEndpointsTest < ActionDispatch::IntegrationTest
  SURFACES = [
    {
      host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
      controller: "acme/app/health",
      liveness_controller: "acme/app/health/liveness",
      readiness_controller: "acme/app/health/readiness",
      startup_controller: "acme/app/health/startup",
      profile: Health::Profiles::App,
    },
    {
      host: ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost"),
      controller: "acme/com/health",
      liveness_controller: "acme/com/health/liveness",
      readiness_controller: "acme/com/health/readiness",
      startup_controller: "acme/com/health/startup",
      profile: Health::Profiles::Com,
    },
    {
      host: ENV.fetch("ACME_STAFF_URL", "www.org.localhost"),
      controller: "acme/org/health",
      liveness_controller: "acme/org/health/liveness",
      readiness_controller: "acme/org/health/readiness",
      startup_controller: "acme/org/health/startup",
      profile: Health::Profiles::Org,
    },
    {
      host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
      controller: "sign/app/health",
      liveness_controller: "sign/app/health/liveness",
      readiness_controller: "sign/app/health/readiness",
      startup_controller: "sign/app/health/startup",
      profile: Health::Profiles::SignApp,
    },
    {
      host: ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost"),
      controller: "sign/com/health",
      liveness_controller: "sign/com/health/liveness",
      readiness_controller: "sign/com/health/readiness",
      startup_controller: "sign/com/health/startup",
      profile: Health::Profiles::SignCom,
    },
    {
      host: ENV.fetch("SIGN_STAFF_URL", "id.org.localhost"),
      controller: "sign/org/health",
      liveness_controller: "sign/org/health/liveness",
      readiness_controller: "sign/org/health/readiness",
      startup_controller: "sign/org/health/startup",
      profile: Health::Profiles::SignOrg,
    },
    {
      host: ENV.fetch("BASE_SERVICE_URL", "base.app.localhost"),
      controller: "base/app/health",
      liveness_controller: "base/app/health/liveness",
      readiness_controller: "base/app/health/readiness",
      startup_controller: "base/app/health/startup",
      profile: Health::Profiles::App,
    },
    {
      host: ENV.fetch("BASE_CORPORATE_URL", "base.com.localhost"),
      controller: "base/com/health",
      liveness_controller: "base/com/health/liveness",
      readiness_controller: "base/com/health/readiness",
      startup_controller: "base/com/health/startup",
      profile: Health::Profiles::Com,
    },
    {
      host: ENV.fetch("BASE_STAFF_URL", "base.org.localhost"),
      controller: "base/org/health",
      liveness_controller: "base/org/health/liveness",
      readiness_controller: "base/org/health/readiness",
      startup_controller: "base/org/health/startup",
      profile: Health::Profiles::Org,
    },
    {
      host: ENV.fetch("PALM_SERVICE_URL", "palm.app.localhost"),
      controller: "palm/app/health",
      liveness_controller: "palm/app/health/liveness",
      readiness_controller: "palm/app/health/readiness",
      startup_controller: "palm/app/health/startup",
      profile: Health::Profiles::App,
    },
    {
      host: ENV.fetch("PALM_CORPORATE_URL", "palm.com.localhost"),
      controller: "palm/com/health",
      liveness_controller: "palm/com/health/liveness",
      readiness_controller: "palm/com/health/readiness",
      startup_controller: "palm/com/health/startup",
      profile: Health::Profiles::Com,
    },
    {
      host: ENV.fetch("PALM_STAFF_URL", "palm.org.localhost"),
      controller: "palm/org/health",
      liveness_controller: "palm/org/health/liveness",
      readiness_controller: "palm/org/health/readiness",
      startup_controller: "palm/org/health/startup",
      profile: Health::Profiles::Org,
    },
    {
      host: ENV.fetch("HELP_SERVICE_URL", "help.app.localhost"),
      controller: "help/app/health",
      liveness_controller: "help/app/health/liveness",
      readiness_controller: "help/app/health/readiness",
      startup_controller: "help/app/health/startup",
      profile: Health::Profiles::App,
    },
    {
      host: ENV.fetch("HELP_CORPORATE_URL", "help.com.localhost"),
      controller: "help/com/health",
      liveness_controller: "help/com/health/liveness",
      readiness_controller: "help/com/health/readiness",
      startup_controller: "help/com/health/startup",
      profile: Health::Profiles::Com,
    },
    {
      host: ENV.fetch("HELP_STAFF_URL", "help.org.localhost"),
      controller: "help/org/health",
      liveness_controller: "help/org/health/liveness",
      readiness_controller: "help/org/health/readiness",
      startup_controller: "help/org/health/startup",
      profile: Health::Profiles::Org,
    },
    {
      host: ENV.fetch("DOCS_SERVICE_URL", "docs.app.localhost"),
      controller: "docs/app/health",
      liveness_controller: "docs/app/health/liveness",
      readiness_controller: "docs/app/health/readiness",
      startup_controller: "docs/app/health/startup",
      profile: Health::Profiles::App,
    },
    {
      host: ENV.fetch("DOCS_CORPORATE_URL", "docs.com.localhost"),
      controller: "docs/com/health",
      liveness_controller: "docs/com/health/liveness",
      readiness_controller: "docs/com/health/readiness",
      startup_controller: "docs/com/health/startup",
      profile: Health::Profiles::Com,
    },
    {
      host: ENV.fetch("DOCS_STAFF_URL", "docs.org.localhost"),
      controller: "docs/org/health",
      liveness_controller: "docs/org/health/liveness",
      readiness_controller: "docs/org/health/readiness",
      startup_controller: "docs/org/health/startup",
      profile: Health::Profiles::Org,
    },
    {
      host: ENV.fetch("NEWS_SERVICE_URL", "news.app.localhost"),
      controller: "news/app/health",
      liveness_controller: "news/app/health/liveness",
      readiness_controller: "news/app/health/readiness",
      startup_controller: "news/app/health/startup",
      profile: Health::Profiles::App,
    },
    {
      host: ENV.fetch("NEWS_CORPORATE_URL", "news.com.localhost"),
      controller: "news/com/health",
      liveness_controller: "news/com/health/liveness",
      readiness_controller: "news/com/health/readiness",
      startup_controller: "news/com/health/startup",
      profile: Health::Profiles::Com,
    },
    {
      host: ENV.fetch("NEWS_STAFF_URL", "news.org.localhost"),
      controller: "news/org/health",
      liveness_controller: "news/org/health/liveness",
      readiness_controller: "news/org/health/readiness",
      startup_controller: "news/org/health/startup",
      profile: Health::Profiles::Org,
    },
    {
      host: ENV.fetch("CORE_SERVICE_URL", "core.app.localhost"),
      controller: "core/app/health",
      liveness_controller: "core/app/health/liveness",
      readiness_controller: "core/app/health/readiness",
      startup_controller: "core/app/health/startup",
      profile: Health::Profiles::App,
    },
    {
      host: ENV.fetch("CORE_CORPORATE_URL", "core.com.localhost"),
      controller: "core/com/health",
      liveness_controller: "core/com/health/liveness",
      readiness_controller: "core/com/health/readiness",
      startup_controller: "core/com/health/startup",
      profile: Health::Profiles::Com,
    },
    {
      host: ENV.fetch("CORE_STAFF_URL", "core.org.localhost"),
      controller: "core/org/health",
      liveness_controller: "core/org/health/liveness",
      readiness_controller: "core/org/health/readiness",
      startup_controller: "core/org/health/startup",
      profile: Health::Profiles::Org,
    },
  ].freeze

  test "surface routes resolve to concrete local controllers with exact profiles" do
    SURFACES.each do |surface|
      assert_health_route(surface[:host], "/health", surface[:controller])
      assert_health_route(surface[:host], "/health/liveness", surface[:liveness_controller])
      assert_health_route(surface[:host], "/health/readiness", surface[:readiness_controller])
      assert_health_route(surface[:host], "/health/startup", surface[:startup_controller])

      [
        surface[:controller],
        surface[:liveness_controller],
        surface[:readiness_controller],
        surface[:startup_controller],
      ].each do |controller|
        controller_class = "#{controller}_controller".camelize.constantize

        assert_same surface[:profile], controller_class.const_get(:HEALTH_PROFILE, false)
      end
    end
  end

  test "all health controllers use the shared rendering concern" do
    SURFACES.each do |surface|
      [
        surface[:controller],
        surface[:liveness_controller],
        surface[:readiness_controller],
        surface[:startup_controller],
      ].each do |controller|
        controller_class = "#{controller}_controller".camelize.constantize

        assert_includes controller_class.ancestors, ::HealthCheckRendering
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

  test "health snapshot is available as json with nested probe dependencies" do
    host! ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")

    get "/health.json"

    assert_equal "application/json", response.media_type
    assert_equal "health", response.parsed_body["check"]
    assert_equal %w(liveness readiness startup), response.parsed_body["dependencies"].keys

    get "/health", headers: { "Accept" => "application/json" }

    assert_equal "application/json", response.media_type
    assert_equal "health", response.parsed_body["check"]
  end

  test "json probes render json regardless of accept header and html suffix" do
    host! ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")

    %w(liveness readiness startup).each do |probe|
      [nil, "text/html", "*/*"].each do |accept|
        headers = accept ? { "Accept" => accept } : {}

        get "/health/#{probe}", headers: headers

        assert_includes [200, 503], response.status
        assert_equal "application/json", response.media_type
        assert_equal probe, response.parsed_body["check"]
        assert_not_predicate response, :redirect?
        assert_nil flash[:alert]
        assert_nil flash[:notice]
      end
    end

    get "/health/readiness.html", headers: { "Accept" => "text/html" }

    assert_equal "application/json", response.media_type
    assert_equal "readiness", response.parsed_body["check"]

    get "/health/startup.html", headers: { "Accept" => "text/html" }

    assert_equal "application/json", response.media_type
    assert_equal "startup", response.parsed_body["check"]
  end

  test "liveness remains dependency free" do
    host! ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")

    Health::ReadinessCheck.stub(:call, ->(_profile:) { raise RuntimeError, "readiness loaded" }) do
      ActiveRecord::Base.stub(:connection, -> { raise RuntimeError, "database touched" }) do
        if defined?(REDIS_CLIENT)
          REDIS_CLIENT.stub(:ping, -> { raise RuntimeError, "redis touched" }) do
            get "/health/liveness"
          end
        else
          get "/health/liveness"
        end
      end
    end

    assert_response :success
    assert_equal "ok", response.parsed_body["status"]
    assert_empty response.parsed_body["dependencies"]
  end

  test "startup remains dependency light" do
    host! ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")

    Health::Checks::Database.stub(:new, ->(*) { raise RuntimeError, "database check built" }) do
      get "/health/startup"
    end

    assert_response :success
    assert_empty response.parsed_body["dependencies"]
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

  test "status codes come from result status" do
    host! ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")

    assert_probe_status(:ok, :success)
    assert_probe_status(:degraded_acceptable, :success)
    assert_probe_status(:unready, :service_unavailable)
  end

  test "public responses omit topology and exception details" do
    host! ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")
    result = Health::CheckResult.new(
      check: :readiness,
      status: :unready,
      surface: Health::Profiles::SignApp.surface_label,
      dependencies: { "database" => "failed" },
    )

    Health::ReadinessCheck.stub(:call, result) do
      get "/health/readiness"
    end

    forbidden = %w(
      AppPrincipalRecord app_principal app_principal_replica writing reading localhost
      StandardError PG::ConnectionBad Mysql2 Redis REDIS_CLIENT
    )

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
        include ::HealthCheckRendering
      end
    inherited_parent =
      Class.new(::ApplicationController) do
        include ::HealthCheckRendering
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
    result = Health::CheckResult.new(
      check: :readiness,
      status: status,
      surface: Health::Profiles::SignApp.surface_label,
    )

    Health::ReadinessCheck.stub(:call, result) do
      get("/health/readiness")
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
        end.new(Health::DependencyResult.new(kind: :database, status: :ok))
      },
    ) do
      get("/health/readiness")
    end

    assert_response :success
  end
end

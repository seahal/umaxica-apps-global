# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class HealthEndpointsTest < ActionDispatch::IntegrationTest
  SURFACES = [
    {
      host: ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost"),
      controller: "auth/app/healths",
      liveness_controller: "auth/app/health/livenesses",
      readiness_controller: "auth/app/health/readinesses",
      startup_controller: "auth/app/health/startups",
      profile: Health::Profiles::SignApp,
    },
    {
      host: ENV.fetch("PRIVATE_AUTH_CORPORATE_URL", "sign.com.localhost"),
      controller: "auth/com/healths",
      liveness_controller: "auth/com/health/livenesses",
      readiness_controller: "auth/com/health/readinesses",
      startup_controller: "auth/com/health/startups",
      profile: Health::Profiles::SignCom,
    },
    {
      host: ENV.fetch("PRIVATE_AUTH_STAFF_URL", "sign.org.localhost"),
      controller: "auth/org/healths",
      liveness_controller: "auth/org/health/livenesses",
      readiness_controller: "auth/org/health/readinesses",
      startup_controller: "auth/org/health/startups",
      profile: Health::Profiles::SignOrg,
    },
    {
      host: ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"),
      controller: "base/app/healths",
      liveness_controller: "base/app/health/livenesses",
      readiness_controller: "base/app/health/readinesses",
      startup_controller: "base/app/health/startups",
      profile: Health::Profiles::App,
    },
    {
      host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"),
      controller: "base/com/healths",
      liveness_controller: "base/com/health/livenesses",
      readiness_controller: "base/com/health/readinesses",
      startup_controller: "base/com/health/startups",
      profile: Health::Profiles::Com,
    },
    {
      host: ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"),
      controller: "base/org/healths",
      liveness_controller: "base/org/health/livenesses",
      readiness_controller: "base/org/health/readinesses",
      startup_controller: "base/org/health/startups",
      profile: Health::Profiles::Org,
    },
    {
      host: ENV.fetch("PUBLIC_PALM_SERVICE_URL"),
      controller: "palm/app/healths",
      liveness_controller: "palm/app/health/livenesses",
      readiness_controller: "palm/app/health/readinesses",
      startup_controller: "palm/app/health/startups",
      profile: Health::Profiles::App,
    },
    {
      host: ENV.fetch("PRIVATE_HELP_SERVICE_URL"),
      controller: "help/app/healths",
      liveness_controller: "help/app/health/livenesses",
      readiness_controller: "help/app/health/readinesses",
      startup_controller: "help/app/health/startups",
      profile: Health::Profiles::App,
    },
    {
      host: ENV.fetch("PRIVATE_HELP_CORPORATE_URL"),
      controller: "help/com/healths",
      liveness_controller: "help/com/health/livenesses",
      readiness_controller: "help/com/health/readinesses",
      startup_controller: "help/com/health/startups",
      profile: Health::Profiles::Com,
    },
    {
      host: ENV.fetch("PRIVATE_HELP_STAFF_URL"),
      controller: "help/org/healths",
      liveness_controller: "help/org/health/livenesses",
      readiness_controller: "help/org/health/readinesses",
      startup_controller: "help/org/health/startups",
      profile: Health::Profiles::Org,
    },
    {
      host: ENV.fetch("PRIVATE_DOCS_SERVICE_URL"),
      controller: "docs/app/healths",
      liveness_controller: "docs/app/health/livenesses",
      readiness_controller: "docs/app/health/readinesses",
      startup_controller: "docs/app/health/startups",
      profile: Health::Profiles::App,
    },
    {
      host: ENV.fetch("PRIVATE_DOCS_CORPORATE_URL"),
      controller: "docs/com/healths",
      liveness_controller: "docs/com/health/livenesses",
      readiness_controller: "docs/com/health/readinesses",
      startup_controller: "docs/com/health/startups",
      profile: Health::Profiles::Com,
    },
    {
      host: ENV.fetch("PRIVATE_DOCS_STAFF_URL"),
      controller: "docs/org/healths",
      liveness_controller: "docs/org/health/livenesses",
      readiness_controller: "docs/org/health/readinesses",
      startup_controller: "docs/org/health/startups",
      profile: Health::Profiles::Org,
    },
    {
      host: ENV.fetch("PRIVATE_NEWS_SERVICE_URL"),
      controller: "news/app/healths",
      liveness_controller: "news/app/health/livenesses",
      readiness_controller: "news/app/health/readinesses",
      startup_controller: "news/app/health/startups",
      profile: Health::Profiles::App,
    },
    {
      host: ENV.fetch("PRIVATE_NEWS_CORPORATE_URL"),
      controller: "news/com/healths",
      liveness_controller: "news/com/health/livenesses",
      readiness_controller: "news/com/health/readinesses",
      startup_controller: "news/com/health/startups",
      profile: Health::Profiles::Com,
    },
    {
      host: ENV.fetch("PRIVATE_NEWS_STAFF_URL"),
      controller: "news/org/healths",
      liveness_controller: "news/org/health/livenesses",
      readiness_controller: "news/org/health/readinesses",
      startup_controller: "news/org/health/startups",
      profile: Health::Profiles::Org,
    },
    {
      host: ENV.fetch("PUBLIC_CORE_SERVICE_URL", ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost")),
      controller: "core/app/healths",
      liveness_controller: "core/app/health/livenesses",
      readiness_controller: "core/app/health/readinesses",
      startup_controller: "core/app/health/startups",
      profile: Health::Profiles::App,
    },
    {
      host: ENV.fetch("PUBLIC_CORE_CORPORATE_URL", ENV.fetch("PUBLIC_CORE_CORPORATE_URL", "core.com.localhost")),
      controller: "core/com/healths",
      liveness_controller: "core/com/health/livenesses",
      readiness_controller: "core/com/health/readinesses",
      startup_controller: "core/com/health/startups",
      profile: Health::Profiles::Com,
    },
    {
      host: ENV.fetch("PUBLIC_CORE_STAFF_URL", ENV.fetch("PUBLIC_CORE_STAFF_URL", "core.org.localhost")),
      controller: "core/org/healths",
      liveness_controller: "core/org/health/livenesses",
      readiness_controller: "core/org/health/readinesses",
      startup_controller: "core/org/health/startups",
      profile: Health::Profiles::Org,
    },
    {
      host: ENV.fetch("PRIVATE_CORE_NETWORK_URL", "core.net.localhost"),
      controller: "core/net/healths",
      liveness_controller: "core/net/health/livenesses",
      readiness_controller: "core/net/health/readinesses",
      startup_controller: "core/net/health/startups",
      profile: Health::Profiles::App,
    },
    {
      host: ENV.fetch("PRIVATE_CORE_DEVELOPER_URL", "core.dev.localhost"),
      controller: "core/dev/healths",
      liveness_controller: "core/dev/health/livenesses",
      readiness_controller: "core/dev/health/readinesses",
      startup_controller: "core/dev/health/startups",
      profile: Health::Profiles::App,
    },
    {
      host: ENV.fetch("PUBLIC_SIDE_SERVICE_URL", "side.app.localhost"),
      controller: "side/app/healths",
      liveness_controller: "side/app/health/livenesses",
      readiness_controller: "side/app/health/readinesses",
      startup_controller: "side/app/health/startups",
      profile: Health::Profiles::App,
    },
    {
      host: ENV.fetch("PUBLIC_SIDE_CORPORATE_URL", "side.com.localhost"),
      controller: "side/com/healths",
      liveness_controller: "side/com/health/livenesses",
      readiness_controller: "side/com/health/readinesses",
      startup_controller: "side/com/health/startups",
      profile: Health::Profiles::Com,
    },
    {
      host: ENV.fetch("PUBLIC_SIDE_STAFF_URL", "side.org.localhost"),
      controller: "side/org/healths",
      liveness_controller: "side/org/health/livenesses",
      readiness_controller: "side/org/health/readinesses",
      startup_controller: "side/org/health/startups",
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

  # One Rails process answers on every surface hostname, and the probe bodies were otherwise
  # identical, so a caller that sent the wrong `Host` still got a 200 and could not tell which
  # surface produced it. The namespace is what makes that detectable.
  test "every probe names the surface that answered" do
    namespaces =
      SURFACES.to_h do |surface|
        host!(surface[:host])

        get("/health/liveness")

        assert_response :success

        expected = surface[:liveness_controller].split("/").first(2).join("/")

        assert_equal expected, response.parsed_body["namespace"],
                     "#{surface[:host]} answered from #{surface[:liveness_controller]} but named " \
                     "#{response.parsed_body["namespace"].inspect}"

        [surface[:host], expected]
      end

    assert_equal namespaces.values.uniq.length, namespaces.values.length,
                 "two hostnames report the same namespace, so a misdirected request between them " \
                 "would still look correct: #{namespaces.inspect}"
  end

  test "readiness and startup name the surface that answered too" do
    surface = SURFACES.first
    host! surface[:host]

    {
      "/health/readiness" => surface[:readiness_controller],
      "/health/startup" => surface[:startup_controller],
    }.each do |path, controller|
      get path

      assert_equal controller.split("/").first(2).join("/"), response.parsed_body["namespace"]
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
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    get "/health"

    assert_response :success
    assert_includes response.media_type, "text/html"
    assert_includes response.body, "Health Snapshot"
    assert_includes response.body, "point-in-time health snapshot"
    assert_includes response.body, "Generated at"
    assert_no_match(/fetch\s*\(/i, response.body)
    assert_no_match(/setInterval|setTimeout|EventSource|WebSocket/i, response.body)
  end

  test "health snapshot does not serve json on any declared surface" do
    SURFACES.each do |surface|
      host! surface[:host]

      get "/health.json"

      assert_not_predicate response, :successful?

      get "/health", headers: { "Accept" => "application/json" }

      assert_not_predicate response, :successful?
    end
  end

  test "health snapshot is available as html with nested probe dependencies" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    get "/health"

    assert_equal "text/html", response.media_type
    assert_includes response.body, "Health Snapshot"
    assert_includes response.body, "Generated at"

    assert_no_match(/health\.json/i, response.body)
  end

  test "json probes render json regardless of accept header and html suffix" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

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
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

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

  test "readiness does not raise prosopite n plus one errors" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    assert_health_request_has_no_prosopite_n_plus_one("/health/readiness")
  end

  test "health snapshot does not raise prosopite n plus one errors" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    assert_health_request_has_no_prosopite_n_plus_one("/health")
  end

  test "startup remains dependency light" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    Health::Checks::Database.stub(:new, ->(*) { raise RuntimeError, "database check built" }) do
      get "/health/startup"
    end

    assert_response :success
    assert_empty response.parsed_body["dependencies"]
  end

  test "app readiness ignores org-only dependencies" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")

    assert_readiness_does_not_build(OrgTicketRecord)
  end

  test "sign readiness ignores acme-only dependencies" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    assert_readiness_does_not_build(AppRpRecord)
  end

  test "new database base classes do not affect existing surfaces by default" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    new_record_base = Class.new(ApplicationRecord)

    assert_readiness_does_not_build(new_record_base)
  end

  test "status codes come from result status" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    assert_probe_status(:ok, :success)
    assert_probe_status(:degraded_acceptable, :success)
    assert_probe_status(:unready, :service_unavailable)
  end

  test "public responses omit topology and exception details" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")
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

  test "every declared health surface executes its controller show actions" do
    SURFACES.each do |surface|
      host! surface[:host]

      profile = surface[:profile]
      liveness = Health::CheckResult.new(check: :liveness, status: :ok, surface: profile.surface_label)
      readiness = Health::CheckResult.new(
        check: :readiness,
        status: :ok,
        surface: profile.surface_label,
        dependencies: {},
      )
      startup = Health::CheckResult.new(check: :startup, status: :ok, surface: profile.surface_label)
      snapshot = Health::CheckResult.new(
        check: :health,
        status: :ok,
        surface: profile.surface_label,
        dependencies: {
          "liveness" => liveness.as_public_json,
          "readiness" => readiness.as_public_json,
          "startup" => startup.as_public_json,
        },
      )

      Health::LivenessCheck.stub(:call, liveness) do
        Health::ReadinessCheck.stub(:call, readiness) do
          Health::StartupCheck.stub(:call, startup) do
            Health::SnapshotCheck.stub(:call, snapshot) do
              get "/health"

              assert_response :success
              assert_equal "text/html", response.media_type
              assert_includes response.body, "Health Snapshot"

              %w(liveness readiness startup).each do |probe|
                get "/health/#{probe}"

                assert_response :success
                assert_equal "application/json", response.media_type
                assert_equal probe, response.parsed_body["check"]
                assert_nil response.parsed_body.dig("details", "surface")
              end
            end
          end
        end
      end
    end
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

  def assert_health_request_has_no_prosopite_n_plus_one(path)
    Prosopite.pause do
      assert_nothing_raised do
        Prosopite.scan do
          get(path)
        end
      end
    end

    assert_includes [200, 503], response.status
    assert_predicate response.media_type, :present?

    Prosopite.pause do
      Prosopite.tc[:prosopite_query_counter] = Hash.new(0)
      Prosopite.tc[:prosopite_query_holder] = Hash.new { |h, k| h[k] = [] }
      Prosopite.tc[:prosopite_query_caller] = {}
    end
  end
end

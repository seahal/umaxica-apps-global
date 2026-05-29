# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageReloadTest < ActiveSupport::TestCase
  test "reloads utility files under coverage" do
    load(Rails.root.join("lib/jit/host_origin_env.rb"))
    load(Rails.root.join("lib/jit/id_host_env.rb"))
    load(Rails.root.join("lib/jit/session_cookie_config.rb"))
    load(Rails.root.join("app/services/analytics_consent_guard.rb"))
    load(Rails.root.join("app/subscribers/jwt_anomaly_subscriber.rb"))

    assert_equal ["http://example.test", "https://example.test"], Jit::HostOriginEnv.trusted_origins("example.test")
    assert_equal ["http://example.test", "https://example.test"], Jit::HostOriginEnv.origins_for("example.test")

    with_env(
      "ID_SERVICE_URL" => "id.app.example.test",
      "ID_CORPORATE_URL" => "id.com.example.test",
      "ID_STAFF_URL" => "id.org.example.test",
    ) do
      assert_equal "id.app.example.test", Jit::IdHostEnv.service_url
      assert_nil Jit::IdHostEnv.validate!
    end

    assert_equal "session", Jit::SessionCookieConfig.cookie_key(force_secure: false)
    assert_not Jit::SessionCookieConfig.partitioned?(rails_env: ActiveSupport::EnvironmentInquirer.new("test"))
    assert_not Jit::SessionCookieConfig.force_secure?(id_service_host: "localhost", rails_env: ActiveSupport::EnvironmentInquirer.new("development"))

    Actor.install_context!(preferences: Actor::Preference::NULL)

    assert AnalyticsConsentGuard.permit?("auth.login.success", preference: Actor.preferences)
    assert_not AnalyticsConsentGuard.permit?("product.page_view", preference: Actor.preferences)

    reporter_class =
      Class.new do
        define_method(:notify) do |name, **payload|
          [:base, name, payload]
        end
      end
    reporter_class.prepend(AnalyticsConsentGuard::EventReporterPatch)

    Actor.stub(:preferences, Actor::Preference::NULL) do
      Rails.logger.stub(:debug, nil) do
        assert_nil reporter_class.new.notify("product.page_view", path: "/")
      end
    end

    Actor.stub(
      :preferences,
      Actor::Preference.new(
        cookie: Actor::Preference::Cookie.new(
          performant: true, functional: true, targetable: false,
          consented: true, consent_version: "1", consented_at: Time.current,
        ),
      ),
    ) do
      assert_equal [:base, "product.page_view", { path: "/" }],
                   reporter_class.new.notify("product.page_view", path: "/")
    end

    subscriber = JwtAnomalySubscriber.new
    mock_event = Struct.new(:name, :payload, :time, keyword_init: true).new(
      name: "other.event",
      payload: { code: "AUTH_USER_MALFORMED_TOKEN" },
      time: Time.current,
    )
    assert_nothing_raised { subscriber.emit(mock_event) }
  ensure
    Actor.reset
  end

  private

  def with_env(vars)
    original = {}
    vars.each_key { |key| original[key] = ENV[key] }

    vars.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end

    yield
  ensure
    original.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end

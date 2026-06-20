# typed: false
# frozen_string_literal: true

require "test_helper"

class AnalyticsConsentGuardTest < ActiveSupport::TestCase
  def preference_without_performant
    cookie = Actor::Preference::Cookie.new(
      consented: true, functional: true, performant: false,
      targetable: false, consent_version: "1", consented_at: Time.current,
    )
    Actor::Preference.new(cookie: cookie)
  end

  def preference_with_performant
    cookie = Actor::Preference::Cookie.new(
      consented: true, functional: true, performant: true,
      targetable: false, consent_version: "1", consented_at: Time.current,
    )
    Actor::Preference.new(cookie: cookie)
  end

  test "allowed event passes without consent" do
    preference = preference_without_performant

    assert AnalyticsConsentGuard.permit?("auth.login.success", preference: preference)
  end

  test "allowed event passes with consent" do
    preference = preference_with_performant

    assert AnalyticsConsentGuard.permit?("auth.login.success", preference: preference)
  end

  test "disallowed event blocked without consent" do
    preference = preference_without_performant

    assert_not AnalyticsConsentGuard.permit?("product.signup.started", preference: preference)
    assert_not AnalyticsConsentGuard.permit?("marketing.pixel.loaded", preference: preference)
  end

  test "disallowed event allowed with consent" do
    preference = preference_with_performant

    assert AnalyticsConsentGuard.permit?("product.signup.started", preference: preference)
    assert AnalyticsConsentGuard.permit?("marketing.pixel.loaded", preference: preference)
  end

  test "security events always pass regardless of consent" do
    preference = preference_without_performant

    assert AnalyticsConsentGuard.permit?("security.csp_violation", preference: preference)
    assert AnalyticsConsentGuard.permit?("rate_limit.triggered", preference: preference)
    assert AnalyticsConsentGuard.permit?("health_check.failed", preference: preference)
    assert AnalyticsConsentGuard.permit?("sign.risk.enforcer.step_up_required", preference: preference)
    assert AnalyticsConsentGuard.permit?("telephone.verification.rate_limited", preference: preference)
  end

  test "null preference blocks disallowed events" do
    assert_not AnalyticsConsentGuard.permit?("product.page_view", preference: Actor::Preference::NULL)
  end

  test "null preference allows pre-consent events" do
    assert AnalyticsConsentGuard.permit?("auth.login.success", preference: Actor::Preference::NULL)
    assert AnalyticsConsentGuard.permit?("authentication.audit.write_failed", preference: Actor::Preference::NULL)
  end

  test "pre-consent allowlist permits auth events" do
    assert AnalyticsConsentGuardPreConsentAllowlist.allowed?("auth.login.success")
  end

  test "pre-consent allowlist permits security events" do
    assert AnalyticsConsentGuardPreConsentAllowlist.allowed?("rate_limit.triggered")
  end

  test "pre-consent allowlist permits incident events" do
    assert AnalyticsConsentGuardPreConsentAllowlist.allowed?("health_check.failed")
  end

  test "pre-consent allowlist permits contact events" do
    assert AnalyticsConsentGuardPreConsentAllowlist.allowed?("contact.submission.sent")
  end

  test "pre-consent allowlist rejects non-allowed events" do
    assert_not AnalyticsConsentGuardPreConsentAllowlist.allowed?("product.page_view")
  end

  test "pre-consent allowlist rejects nil and empty event names" do
    assert_not AnalyticsConsentGuardPreConsentAllowlist.allowed?(nil)
    assert_not AnalyticsConsentGuardPreConsentAllowlist.allowed?("")
  end

  test "event reporter patch drops blocked events and forwards allowed events" do
    reporter_class =
      Class.new do
        define_method(:notify) do |name, **payload|
          [:base, name, payload]
        end
      end
    reporter_class.prepend(AnalyticsConsentGuard::EventReporterPatch)

    blocked_preference = preference_without_performant
    allowed_preference = preference_with_performant

    Actor.stub(:preferences, blocked_preference) do
      Rails.logger.stub(:debug, nil) do
        assert_nil reporter_class.new.notify("product.page_view", path: "/")
      end
    end

    Actor.stub(:preferences, allowed_preference) do
      assert_equal [:base, "product.page_view", { path: "/" }],
                   reporter_class.new.notify("product.page_view", path: "/")
    end
  end
end

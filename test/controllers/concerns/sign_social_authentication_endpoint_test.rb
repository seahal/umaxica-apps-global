# typed: false
# frozen_string_literal: true

require "test_helper"

# Unlinking a social identity is a credential removal, so it is gated by a
# stealth challenge and every provider-side failure has its own answer: the last
# remaining identity cannot be removed at all, and any other provider error is
# rendered with the status that error names rather than a generic 500.
class SignSocialAuthenticationEndpointTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness(&definition)
    Class.new(ApplicationController) do
      include SignSocialAuthenticationEndpoint

      attr_accessor :redirected, :rendered

      def cloudflare_turnstile_stealth_validation = { "success" => true }

      def current_client = nil

      def social_unlink_success_path(provider) = "/settings/#{provider}"

      def social_unlink_failure_path(provider) = "/settings/#{provider}?error=1"

      def redirect_to(*args, **kwargs)
        self.redirected = [args, kwargs]
      end

      def render(*args, **kwargs)
        self.rendered = [args, kwargs]
      end

      def invoke(name, ...) = send(name, ...)

      class_eval(&definition) if definition
    end.new
  end

  test "the last remaining social identity cannot be unlinked" do
    subject = harness
    failing = ->(**) { raise SocialAuth::LastIdentityError, "errors.social_auth.last_identity" }

    ExternalAuthenticationUnlinkUseCase.stub(:call, failing) do
      subject.invoke(:disconnect_social_authentication, provider: "google")
    end

    assert_equal "/settings/google?error=1", subject.redirected.first.first
    assert_equal :see_other, subject.redirected.last.fetch(:status)
  end

  test "any other provider failure is rendered with the status that failure names" do
    subject = harness
    failing = ->(**) { raise SocialAuth::ProviderError, "errors.social_auth.provider_error" }

    ExternalAuthenticationUnlinkUseCase.stub(:call, failing) do
      subject.invoke(:disconnect_social_authentication, provider: "google")
    end

    assert_equal I18n.t("errors.social_auth.provider_error"), subject.rendered.last.fetch(:plain)
    assert_not_includes subject.rendered.last.fetch(:plain), "Translation missing"
  end

  test "a successful unlink returns to the provider settings page" do
    subject = harness

    ExternalAuthenticationUnlinkUseCase.stub(:call, ->(**) { true }) do
      subject.invoke(:disconnect_social_authentication, provider: "google")
    end

    assert_equal "/settings/google", subject.redirected.first.first
  end
end

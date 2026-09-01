# typed: false
# frozen_string_literal: true

require "test_helper"

# Two more shared defaults. The recovery-passcode requirement counts one strong
# credential as the threshold unless a surface says otherwise, and the authorize
# rate limiter records a near-limit warning before it starts refusing, so the
# refusal is never the first signal an operator sees.
class RecoveryAndRateLimitSeamsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "the recovery passcode requirement counts one strong credential by default" do
    subject = Class.new { include SignRequiresRecoveryPasscodes }.new

    assert_equal 1, subject.send(:recovery_passcode_requirement_active_strong_credential_count)
  end

  test "the authorize rate limiter records a near-limit warning before it refuses" do
    subject = Class.new(ActionController::Base) do
      include OauthAuthorizeRateLimit

      def self.name = "Base::Com::Oauth::AuthorizationsController"
    end.new
    subject.request = ActionDispatch::TestRequest.create
    recorded = []

    Rails.logger.stub(:info, ->(*args, &block) { recorded << (args.first || block&.call).to_s }) do
      subject.send(
        :oauth_authorize_rate_limit_near_limit!,
        bucket: "browser_client",
        profile: Struct.new(:to, :within, :name, :retry_after).new(60, 60, "browser_client", 60),
        count: 55,
      )
    end

    assert(recorded.any? { |line| line.include?("oidc.authorize.rate_limit.near_limit") })
  end
end

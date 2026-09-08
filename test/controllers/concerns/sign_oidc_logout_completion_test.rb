# typed: false
# frozen_string_literal: true

require "test_helper"

# Ending an OIDC session hands control back to whoever started it. A relying
# party that registered a post-logout target is sent there through the jump
# gateway; everything else lands on this surface's own completion page. A
# completion URL that cannot be parsed is used as given rather than dropped, so
# the ceremony still ends somewhere.
class SignOidcLogoutCompletionTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness(&definition)
    Class.new(ApplicationController) do
      include SignOidcLogout

      attr_accessor :redirected, :rendered, :consumed, :params_hash

      def params
        ActionController::Parameters.new(params_hash || {})
      end

      def redirect_to(*args, **kwargs)
        self.redirected = [args, kwargs]
      end

      def render(*args, **kwargs)
        self.rendered = [args, kwargs]
      end

      def consume_sign_out_notice
        self.consumed = true
        { "access_expires_at" => nil }
      end

      def oidc_logout_completed_path(**options) = "/sign/out/complete?#{options.compact.to_query}"

      def invoke(name, ...) = send(name, ...)

      class_eval(&definition) if definition
    end.new.tap { |h| h.params_hash = { ri: "jp" } }
  end

  test "the completion page consumes the sign-out notice exactly once" do
    subject = harness

    subject.invoke(:render_oidc_logout_completion)

    assert subject.consumed
    assert_equal :ok, subject.rendered.last.fetch(:status)
  end

  test "a completion url the parser cannot read is used as the relying party gave it" do
    subject = harness
    transaction = Struct.new(:origin_surface, :completion_url, :logout_challenge, :callback_state)
      .new("palm", "https://[", "challenge-1", nil)

    assert_equal "https://[", subject.invoke(:oidc_logout_completion_redirect_url, transaction)
  end

  test "a completion url for a surface that does not rewrite it is returned unchanged" do
    subject = harness
    transaction = Struct.new(:origin_surface, :completion_url, :logout_challenge, :callback_state)
      .new("sign", "https://auth.example/done", "challenge-1", nil)

    assert_equal "https://auth.example/done", subject.invoke(:oidc_logout_completion_redirect_url, transaction)
  end
end

class SignOidcLogoutCompletionTest
  test "OIDC logout pending and token helpers reject stale or absent records" do
    subject = harness
    session_hash = {}
    subject.define_singleton_method(:session) { session_hash }
    subject.params_hash = {}

    assert_not subject.invoke(:oidc_logout_pending_request_present?)
    assert_nil subject.invoke(:oidc_logout_pending_request)
    subject.params_hash = { logout_challenge: "challenge-1" }

    assert subject.invoke(:oidc_logout_pending_request_present?)
    assert_equal "challenge-1", subject.invoke(:oidc_logout_pending_request).logout_challenge
    subject.params_hash = {}
    session_hash[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY] = { "expires_at" => 1.minute.ago.iso8601 }

    assert_nil subject.invoke(:oidc_logout_pending_request)
    session_hash[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY] = { "expires_at" => 1.minute.from_now.iso8601 }

    assert_instance_of SignOidcLogout::OidcLogoutPendingRequest, subject.invoke(:oidc_logout_pending_request)

    assert_nil subject.invoke(:oidc_current_session_token, nil)
    assert_nil subject.invoke(:revoke_oidc_current_session_token!, nil)
  end

  test "logout redirect and service host helpers cover no-state and each surface" do
    subject = harness
    result = Struct.new(:post_logout_redirect_uri, :state).new("https://client.example/done", nil)

    assert_equal result.post_logout_redirect_uri, subject.invoke(:post_logout_redirect_uri_with_state, result)
    subject.define_singleton_method(:controller_path) { "auth/app/sign/out" }

    assert_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), subject.invoke(:sign_service_host)
    subject.define_singleton_method(:controller_path) { "auth/com/sign/out" }

    assert_equal ENV.fetch("PRIVATE_AUTH_CORPORATE_URL"), subject.invoke(:sign_service_host)
    subject.define_singleton_method(:controller_path) { "auth/org/sign/out" }

    assert_equal ENV.fetch("PRIVATE_AUTH_STAFF_URL"), subject.invoke(:sign_service_host)
    subject.define_singleton_method(:params) { ActionController::Parameters.new({}) }

    assert_nil subject.invoke(:logout_transaction_for_challenge)
  end
end

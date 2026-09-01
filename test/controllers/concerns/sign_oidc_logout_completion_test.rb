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
    Class.new(ActionController::Base) do
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

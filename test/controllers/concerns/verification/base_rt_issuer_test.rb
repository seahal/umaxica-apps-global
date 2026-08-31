# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class VerificationBaseRtIssuerTest < ActiveSupport::TestCase
  Request =
    Struct.new(:parameters, :host, :fullpath, :request_id, keyword_init: true) do
      def parameters
        self[:parameters] || {}
      end
    end

  TokenStub = Struct.new(:public_id)

  module Sign
    module App
      class RtHarness
        class << self
          def before_action(*) = nil

          def helper_method(*) = nil
        end

        include CommonRedirect
        include VerificationBase

        attr_accessor :rt_param, :session_token, :request_fullpath

        def request
          Request.new(
            parameters: { "pt" => rt_param.to_s },
            host: "id.app.localhost",
            fullpath: request_fullpath || "/settings/passkeys",
            request_id: "req-1",
          )
        end

        def params
          { pt: rt_param }.with_indifferent_access
        end

        def current_session_token = session_token

        # mirrors authentication_base: returns the stable session identifier
        def current_session_public_id = session_token&.public_id.to_s

        def actor_verification_path = "/sign/app/verification"
      end
    end

    module Com
      class RtHarness < Sign::App::RtHarness
        def actor_verification_path = "/sign/com/verification"
      end
    end

    module Org
      class RtHarness < Sign::App::RtHarness
        def actor_verification_path = "/sign/org/verification"
      end
    end
  end

  module NoSurface
    class RtHarness < Sign::App::RtHarness
    end
  end

  test "encoded_relative_pt issues a signed token when surface + session are known" do
    h = Sign::App::RtHarness.new
    h.session_token = TokenStub.new("nonce-1")

    pt = h.send(:encoded_relative_pt, "/settings/passkeys/9")

    assert_includes pt, "--", "expected signed format (verifier appends -- separator), got: #{pt.inspect}"

    resolved = h.send(:resolve_step_up_pt, pt)

    assert_equal "/settings/passkeys/9", resolved
  end

  test "encoded_step_up_pt issues a signed token derived from request.fullpath" do
    h = Sign::App::RtHarness.new
    h.session_token = TokenStub.new("nonce-1")
    h.request_fullpath = "/settings/secrets"

    pt = h.send(:encoded_step_up_pt)

    assert_includes pt, "--", "expected signed format"
    assert_equal "/settings/secrets", h.send(:resolve_step_up_pt, pt)
  end

  test "issue_step_up_pt returns nil when surface cannot be inferred" do
    h = NoSurface::RtHarness.new
    h.session_token = TokenStub.new("nonce-1")

    pt = h.send(:encoded_relative_pt, "/settings/passkeys/9")

    assert_nil pt
  end

  test "issue_step_up_pt returns nil when no session token is available" do
    h = Sign::App::RtHarness.new
    h.session_token = nil

    pt = h.send(:encoded_relative_pt, "/settings/passkeys/9")

    assert_nil pt
  end

  test "resolve_step_up_pt rejects signed tokens cross-surface" do
    issuer = Sign::App::RtHarness.new
    issuer.session_token = TokenStub.new("nonce-1")
    pt = issuer.send(:encoded_relative_pt, "/settings/passkeys/9")

    consumer = Sign::Com::RtHarness.new
    consumer.session_token = TokenStub.new("nonce-1")

    assert_nil consumer.send(:resolve_step_up_pt, pt)
  end

  test "resolve_step_up_pt rejects signed tokens issued for a different session" do
    issuer = Sign::App::RtHarness.new
    issuer.session_token = TokenStub.new("nonce-issuer")
    pt = issuer.send(:encoded_relative_pt, "/settings/passkeys/9")

    consumer = Sign::App::RtHarness.new
    consumer.session_token = TokenStub.new("nonce-consumer")

    assert_nil consumer.send(:resolve_step_up_pt, pt)
  end

  # Regression test: when the access token is rotated between the settings redirect and the
  # verification page, bootstrap_pt_session_nonce must not change.  The harness models this by
  # keeping current_session_public_id stable while swapping session_token (which now holds a
  # different token.public_id, as happens in production after AcmeRefreshTokenIssuer rotates).
  test "resolve_step_up_pt accepts a pt that was issued before an access-token rotation" do
    # Simulate the session identifier (device_session.public_id in production) that is stable
    # across token rotations.
    stable_session_id = "device-session-pub-id"

    # Step 1 - settings page: original token + stable session id -> issue pt
    issuer = Sign::App::RtHarness.new
    issuer.session_token = TokenStub.new("token-before-rotation")
    issuer.define_singleton_method(:current_session_public_id) { stable_session_id }
    pt = issuer.send(:encoded_relative_pt, "/settings/emails")

    # Step 2 - verification page: access token rotated, token.public_id has changed.
    # current_session_public_id still returns the same stable_session_id.
    consumer = Sign::App::RtHarness.new
    consumer.session_token = TokenStub.new("token-after-rotation")
    consumer.define_singleton_method(:current_session_public_id) { stable_session_id }

    assert_equal "/settings/emails", consumer.send(:resolve_step_up_pt, pt)
  end

  test "decode_pt_path accepts signed tokens and rejects legacy tokens" do
    h = Sign::App::RtHarness.new
    h.session_token = TokenStub.new("nonce-1")
    signed = h.send(:encoded_relative_pt, "/settings/passkeys/9")
    legacy = Base64.urlsafe_encode64("/settings/legacy")

    assert_equal "/settings/passkeys/9", h.send(:decode_pt_path, signed)
    assert_nil h.send(:decode_pt_path, legacy)
    assert_nil h.send(:decode_pt_path, "garbage~~")
    assert_nil h.send(:decode_pt_path, nil)
    assert_nil h.send(:decode_pt_path, "")
  end

  # The setup screen returns to where the person came from, except that it refuses to
  # send them back into another settings page mid-ceremony: those collapse to the
  # surface's settings root instead.
  test "setup_pt_path collapses a settings destination to the settings root" do
    h = Sign::App::RtHarness.new
    h.session_token = TokenStub.new("nonce-1")

    settings_pt = h.send(:encoded_relative_pt, "/settings/passkeys/9")

    assert_equal "/settings", h.send(:setup_pt_path, settings_pt, root_path: "/settings")

    other_pt = h.send(:encoded_relative_pt, "/identity/emails")

    assert_equal "/identity/emails", h.send(:setup_pt_path, other_pt, root_path: "/settings")
  end

  test "setup_pt_path answers nil for a blank or unparsable destination" do
    h = Sign::App::RtHarness.new
    h.session_token = TokenStub.new("nonce-1")

    assert_nil h.send(:setup_pt_path, nil, root_path: "/settings")

    h.stub(:decode_pt_path, "http://[not-a-uri") do
      assert_nil h.send(:setup_pt_path, "anything", root_path: "/settings")
    end
  end

  # The concern defaults to the client verification record; the staff surface flips
  # both the model and the foreign key by overriding actor_operator?.
  test "verification model and token foreign key follow the actor kind" do
    h = Sign::App::RtHarness.new

    assert_equal ClientVerification, h.send(:verification_model)
    assert_equal :user_token_id, h.send(:verification_token_foreign_key)
    assert_equal %i(email_otp passkey totp), h.send(:step_up_supported_methods)

    h.define_singleton_method(:actor_operator?) { true }

    assert_equal OperatorVerification, h.send(:verification_model)
    assert_equal :staff_token_id, h.send(:verification_token_foreign_key)
    assert_equal [:passkey], h.send(:step_up_supported_methods)
  end

  test "current_step_up_ticket answers nil when the session cannot carry one" do
    h = Sign::App::RtHarness.new
    h.session_token = TokenStub.new("nonce-1")

    assert_nil h.send(:current_step_up_ticket)
  end

  test "unwrap_verification_pt_path unwraps nested signed pt" do
    h = Sign::App::RtHarness.new
    h.session_token = TokenStub.new("nonce-1")

    inner_rt = h.send(:encoded_relative_pt, "/settings/passkeys/9")
    nested_path = "/sign/app/verification?ri=jp&pt=#{inner_rt}"

    unwrapped = h.send(:unwrap_verification_pt_path, nested_path)

    assert_equal "/settings/passkeys/9", unwrapped
  end

  test "existing_step_up_pt_path resolves signed params and rejects legacy params" do
    h = Sign::App::RtHarness.new
    h.session_token = TokenStub.new("nonce-1")
    signed = h.send(:encoded_relative_pt, "/settings/passkeys/9")
    h.rt_param = signed

    assert_equal "/settings/passkeys/9", h.send(:existing_step_up_pt_path)

    h.rt_param = Base64.urlsafe_encode64("/settings/legacy")

    assert_nil h.send(:existing_step_up_pt_path)
  end
end

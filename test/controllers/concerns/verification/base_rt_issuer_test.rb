# typed: false
# frozen_string_literal: true

require "test_helper"

class Verification::BaseRtIssuerTest < ActiveSupport::TestCase
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

        include Common::Redirect
        include Verification::Base

        attr_accessor :rt_param, :session_token, :request_fullpath

        def request
          Request.new(
            parameters: { "rt" => rt_param.to_s },
            host: "id.app.localhost",
            fullpath: request_fullpath || "/configuration/passkeys",
            request_id: "req-1",
          )
        end

        def params
          { rt: rt_param }.with_indifferent_access
        end

        def current_session_token = session_token

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

  test "encoded_relative_return_to issues a signed token when surface + session are known" do
    h = Sign::App::RtHarness.new
    h.session_token = TokenStub.new("nonce-1")

    rt = h.send(:encoded_relative_return_to, "/configuration/passkeys/9")

    assert_includes rt, "--", "expected signed format (verifier appends -- separator), got: #{rt.inspect}"

    resolved = h.send(:resolve_step_up_rt, rt)

    assert_equal "/configuration/passkeys/9", resolved
  end

  test "encoded_step_up_rt issues a signed token derived from request.fullpath" do
    h = Sign::App::RtHarness.new
    h.session_token = TokenStub.new("nonce-1")
    h.request_fullpath = "/configuration/secrets"

    rt = h.send(:encoded_step_up_rt)

    assert_includes rt, "--", "expected signed format"
    assert_equal "/configuration/secrets", h.send(:resolve_step_up_rt, rt)
  end

  test "issue_step_up_rt returns nil when surface cannot be inferred" do
    h = NoSurface::RtHarness.new
    h.session_token = TokenStub.new("nonce-1")

    rt = h.send(:encoded_relative_return_to, "/configuration/passkeys/9")

    assert_nil rt
  end

  test "issue_step_up_rt returns nil when no session token is available" do
    h = Sign::App::RtHarness.new
    h.session_token = nil

    rt = h.send(:encoded_relative_return_to, "/configuration/passkeys/9")

    assert_nil rt
  end

  test "resolve_step_up_rt rejects signed tokens cross-surface" do
    issuer = Sign::App::RtHarness.new
    issuer.session_token = TokenStub.new("nonce-1")
    rt = issuer.send(:encoded_relative_return_to, "/configuration/passkeys/9")

    consumer = Sign::Com::RtHarness.new
    consumer.session_token = TokenStub.new("nonce-1")

    assert_nil consumer.send(:resolve_step_up_rt, rt)
  end

  test "resolve_step_up_rt rejects signed tokens issued for a different session" do
    issuer = Sign::App::RtHarness.new
    issuer.session_token = TokenStub.new("nonce-issuer")
    rt = issuer.send(:encoded_relative_return_to, "/configuration/passkeys/9")

    consumer = Sign::App::RtHarness.new
    consumer.session_token = TokenStub.new("nonce-consumer")

    assert_nil consumer.send(:resolve_step_up_rt, rt)
  end

  test "decode_return_to_path accepts signed tokens and rejects legacy tokens" do
    h = Sign::App::RtHarness.new
    h.session_token = TokenStub.new("nonce-1")
    signed = h.send(:encoded_relative_return_to, "/configuration/passkeys/9")
    legacy = Base64.urlsafe_encode64("/configuration/legacy")

    assert_equal "/configuration/passkeys/9", h.send(:decode_return_to_path, signed)
    assert_nil h.send(:decode_return_to_path, legacy)
    assert_nil h.send(:decode_return_to_path, "garbage~~")
    assert_nil h.send(:decode_return_to_path, nil)
    assert_nil h.send(:decode_return_to_path, "")
  end

  test "unwrap_verification_return_to_path unwraps nested signed rt" do
    h = Sign::App::RtHarness.new
    h.session_token = TokenStub.new("nonce-1")

    inner_rt = h.send(:encoded_relative_return_to, "/configuration/passkeys/9")
    nested_path = "/sign/app/verification?ri=jp&rt=#{inner_rt}"

    unwrapped = h.send(:unwrap_verification_return_to_path, nested_path)

    assert_equal "/configuration/passkeys/9", unwrapped
  end

  test "existing_step_up_return_to_path resolves signed params and rejects legacy params" do
    h = Sign::App::RtHarness.new
    h.session_token = TokenStub.new("nonce-1")
    signed = h.send(:encoded_relative_return_to, "/configuration/passkeys/9")
    h.rt_param = signed

    assert_equal "/configuration/passkeys/9", h.send(:existing_step_up_return_to_path)

    h.rt_param = Base64.urlsafe_encode64("/configuration/legacy")

    assert_nil h.send(:existing_step_up_return_to_path)
  end
end

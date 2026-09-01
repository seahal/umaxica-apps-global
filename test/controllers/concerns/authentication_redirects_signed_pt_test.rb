# typed: false
# frozen_string_literal: true

require "test_helper"

# Why a signed path-target was refused is logged, so the reason string has to
# distinguish a missing token from a malformed one, an expired signature, and a
# token that verified but was rejected further in. The verification itself maps
# an invalid signature to :expired and anything else to nil.
class AuthenticationRedirectsSignedPtTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness
    include AuthenticationRedirects

    attr_accessor :payload_result, :payload_error

    def invoke(name, ...) = send(name, ...)

    def authentication_pt_flow = "flow"

    def authentication_pt_surface = "app"

    def authentication_pt_session_nonce = "nonce"

    def verified_signed_target_payload(*, **)
      raise payload_error if payload_error

      payload_result
    end
  end

  setup { @harness = Harness.new }

  test "signed_pt_rejection_reason names why the token was refused" do
    assert_equal "missing", @harness.invoke(:signed_pt_rejection_reason, nil)
    assert_equal "missing", @harness.invoke(:signed_pt_rejection_reason, "")
    assert_equal "malformed", @harness.invoke(:signed_pt_rejection_reason, 42)

    @harness.payload_result = :expired

    assert_equal "expired", @harness.invoke(:signed_pt_rejection_reason, "token")

    @harness.payload_result = nil

    assert_equal "signature_invalid", @harness.invoke(:signed_pt_rejection_reason, "token")

    @harness.payload_result = { "pt" => "/settings" }

    assert_equal "verifier_error", @harness.invoke(:signed_pt_rejection_reason, "token")
  end

  test "signed_pt_verification_payload maps an invalid signature to expired and other errors to nil" do
    @harness.payload_error = ActiveSupport::MessageVerifier::InvalidSignature

    assert_equal :expired, @harness.invoke(:signed_pt_verification_payload, "token")

    @harness.payload_error = ArgumentError

    assert_nil @harness.invoke(:signed_pt_verification_payload, "token")
  end
end

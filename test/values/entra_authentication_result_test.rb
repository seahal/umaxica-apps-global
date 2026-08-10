# typed: false
# frozen_string_literal: true

require "test_helper"

class EntraAuthenticationResultTest < ActiveSupport::TestCase
  test "verified result exposes normalized Entra identity evidence" do
    authentication = EntraAuthenticationResult.verified(
      tenant_id: "11111111-2222-3333-4444-555555555555",
      entra_object_id: "ffffffff-eeee-dddd-cccc-bbbbbbbbbbbb",
      evidence_issuer: "https://login.microsoftonline.com/11111111-2222-3333-4444-555555555555/v2.0",
      evidence_subject: "pairwise-subject",
    )

    assert_predicate authentication, :verified?
    assert_not_predicate authentication, :rejected?
    assert_equal :verified, authentication.status
    assert_nil authentication.error
  end

  test "rejected result exposes only the machine-readable error" do
    authentication = EntraAuthenticationResult.rejected(error: "nonce_mismatch")

    assert_predicate authentication, :rejected?
    assert_not_predicate authentication, :verified?
    assert_equal :rejected, authentication.status
    assert_equal "nonce_mismatch", authentication.error
    assert_nil authentication.tenant_id
    assert_nil authentication.entra_object_id
  end
end

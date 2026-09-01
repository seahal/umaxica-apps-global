# typed: false
# frozen_string_literal: true

require "test_helper"

# Sign-out audit and page copy are derived from request data that a caller
# controls: the Origin header, the fetch metadata headers, and the expiry claim
# on a token. Each derivation has to answer something safe for input it cannot
# parse, because the sign-out itself must still complete.
class SignOutNoticeHelpersTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness < ActionController::Base
    include SignOutNotice

    def invoke(name, ...) = send(name, ...)
  end

  setup do
    @harness = Harness.new
  end

  test "an origin the URI parser rejects is logged as invalid rather than raising" do
    assert_equal "auth.example", @harness.invoke(:origin_host_for_sign_out_log, "https://auth.example")
    assert_nil @harness.invoke(:origin_host_for_sign_out_log, "")
    assert_equal "invalid", @harness.invoke(:origin_host_for_sign_out_log, "https://[")
  end

  test "each fetch-metadata rejection is reported by its own reason" do
    assert_equal "missing_sec_fetch_site", @harness.invoke(:fetch_metadata_rejection_reason, "", true)
    assert_equal "invalid_sec_fetch_site", @harness.invoke(:fetch_metadata_rejection_reason, "cross-site", true)
    assert_equal "untrusted_origin", @harness.invoke(:fetch_metadata_rejection_reason, "same-origin", false)
    assert_equal "invalid_request", @harness.invoke(:fetch_metadata_rejection_reason, "same-origin", true)
  end

  test "the completion copy names the access expiry once one is known" do
    assert_nil @harness.invoke(:sign_out_completed_description)

    @harness.instance_variable_set(:@sign_out_access_expires_at, Time.zone.local(2026, 9, 1, 12, 0, 0))

    assert_predicate @harness.invoke(:sign_out_completed_description), :present?
  end

  test "an expiry claim that is not an integer resolves to no expiry rather than raising" do
    assert_nil @harness.invoke(:access_expires_at_from_claims, nil)
    assert_nil @harness.invoke(:access_expires_at_from_claims, { "exp" => "not-a-number" })
    assert_equal Time.zone.at(1_756_000_000),
                 @harness.invoke(:access_expires_at_from_claims, { "exp" => 1_756_000_000 })
  end
end

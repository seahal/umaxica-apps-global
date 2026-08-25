# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcClientFlipperActorTest < ActiveSupport::TestCase
  test "the flipper id namespaces the client id" do
    assert_equal "oidc_client;sign-rp", OidcClientFlipperActor.new(client_id: "sign-rp").flipper_id
  end

  # Two relying parties must never share a gate, and a client id must never
  # collide with an identifier from some other actor type.
  test "distinct client ids produce distinct flipper ids" do
    assert_not_equal(
      OidcClientFlipperActor.new(client_id: "sign-rp").flipper_id,
      OidcClientFlipperActor.new(client_id: "other-rp").flipper_id,
    )
  end
end

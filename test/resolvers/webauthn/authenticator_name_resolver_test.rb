# typed: false
# frozen_string_literal: true

require "test_helper"

class WebauthnAuthenticatorNameResolverTest < ActiveSupport::TestCase
  test "resolves a catalogued AAGUID to a friendly name with its source" do
    result = Webauthn::AuthenticatorNameResolver.resolve("ea9b8d66-4d01-1d21-3ce4-b6b48cb575d4")

    assert_equal "Google Password Manager", result.name
    assert_equal "local_catalog", result.source
  end

  test "resolution is case-insensitive on the AAGUID" do
    result = Webauthn::AuthenticatorNameResolver.resolve("EA9B8D66-4D01-1D21-3CE4-B6B48CB575D4")

    assert_equal "Google Password Manager", result.name
  end

  test "returns nil for blank and unknown AAGUIDs instead of raising" do
    assert_nil Webauthn::AuthenticatorNameResolver.resolve(nil)
    assert_nil Webauthn::AuthenticatorNameResolver.resolve("")
    assert_nil Webauthn::AuthenticatorNameResolver.resolve(SecureRandom.uuid)
  end

  test "catalog keys are lowercase canonical UUIDs with non-empty names" do
    Webauthn::AuthenticatorNameResolver.catalog.each do |aaguid, name|
      assert_match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/, aaguid)
      assert_equal aaguid, aaguid.downcase
      assert_predicate name.to_s.strip, :present?
    end
  end

  test "metadata attributes leave provider fields nil for unknown AAGUIDs" do
    context = Webauthn::AuthenticationContext.new(
      webauthn_id: "id", user_verified: true, user_present: true, sign_count: 1,
      backup_eligible: false, backup_state: false, aaguid: SecureRandom.uuid,
      transports: %w(internal), authenticator_attachment: "platform", verified_at: Time.current,
    )

    attributes = Webauthn::AuthenticatorMetadata.attributes_from(context)

    assert_nil attributes[:provider_name]
    assert_nil attributes[:metadata_source]
    assert_equal context.aaguid, attributes[:aaguid]
    assert_equal %w(internal), attributes[:transports]
  end

  test "permit restricts input to the metadata columns" do
    permitted = Webauthn::AuthenticatorMetadata.permit(
      "aaguid" => "x", "provider_name" => "y", "webauthn_id" => "evil", "user_id" => 1,
    )

    assert_equal "x", permitted[:aaguid]
    assert_equal "y", permitted[:provider_name]
    assert_not_includes permitted.keys, :webauthn_id
    assert_not_includes permitted.keys, :user_id
    assert_empty Webauthn::AuthenticatorMetadata.permit(nil)
  end
end

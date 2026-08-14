# typed: false
# frozen_string_literal: true

require "test_helper"

module ExternalAuthentication
  class EntraProviderAdapterTest < ActiveSupport::TestCase
    TENANT_ID = "11111111-2222-3333-4444-555555555555"
    OBJECT_ID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    CLIENT_ID = "22222222-3333-4444-5555-666666666666"

    test "requires an audience" do
      assert_raises(ArgumentError) { EntraProviderAdapter.new(audience: nil) }
      assert_raises(ArgumentError) { EntraProviderAdapter.new(audience: "") }
    end

    test "returns a verified principal carrying the Entra tenant context" do
      result = call(auth_hash)

      assert_predicate result, :verified?

      principal = result.principal

      assert_equal "entra", principal.provider
      assert_equal "pairwise-sub", principal.subject
      assert_equal "https://login.microsoftonline.com/#{TENANT_ID}/v2.0", principal.issuer
      assert_equal CLIENT_ID, principal.audience
      assert_equal TENANT_ID, principal.tenant_context.tenant_id
      assert_equal OBJECT_ID, principal.tenant_context.object_identifier
    end

    test "carries no raw token or credential candidate" do
      result = call(auth_hash)

      assert_nil result.credential_candidate
      assert_not result.principal.respond_to?(:id_token)
    end

    test "fails typed when the AuthHash is not an AuthHash" do
      result = call({ "provider" => "entra" })

      assert_predicate result, :failed?
      assert_equal :invalid_callback, result.failure.code
      assert_equal :callback_invalid, result.failure.safe_reason
    end

    test "fails typed for another provider's AuthHash" do
      result = call(auth_hash(provider: "google"))

      assert_predicate result, :failed?
      assert_equal :provider_mismatch, result.failure.safe_reason
    end

    test "fails typed when tid or oid is not a UUID" do
      %w(tid oid).each do |claim|
        result = call(auth_hash(raw_info_overrides: { claim => "not-a-uuid" }))

        assert_predicate result, :failed?, "expected a malformed #{claim} to fail"
        assert_equal :assertion_invalid, result.failure.safe_reason
      end
    end

    test "fails typed when sub or iss is missing" do
      %w(sub iss).each do |claim|
        result = call(auth_hash(raw_info_overrides: { claim => "" }))

        assert_predicate result, :failed?, "expected a missing #{claim} to fail"
        assert_equal :assertion_invalid, result.failure.safe_reason
      end
    end

    test "fails typed when raw_info is absent" do
      result = call(OmniAuth::AuthHash.new(provider: "entra", uid: "x"))

      assert_predicate result, :failed?
      assert_equal :callback_invalid, result.failure.safe_reason
    end

    test "the factory builds this adapter for the entra provider" do
      adapter = ProviderAdapterFactory.build(provider: "entra", audience: CLIENT_ID)

      assert_instance_of EntraProviderAdapter, adapter
    end

    private

    def call(hash)
      EntraProviderAdapter.new(audience: CLIENT_ID).call(auth_hash: hash, verified_at: Time.current)
    end

    def auth_hash(provider: "entra", raw_info_overrides: {})
      OmniAuth::AuthHash.new(
        provider: provider,
        uid: "#{TENANT_ID}:#{OBJECT_ID}",
        extra: {
          raw_info: {
            "tid" => TENANT_ID,
            "oid" => OBJECT_ID,
            "iss" => "https://login.microsoftonline.com/#{TENANT_ID}/v2.0",
            "sub" => "pairwise-sub",
          }.merge(raw_info_overrides),
        },
      )
    end
  end
end

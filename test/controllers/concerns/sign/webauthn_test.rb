# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  class WebauthnTest < ActionDispatch::IntegrationTest
    class TestController < ApplicationController
      include PasskeyCeremonyContext

      webauthn_surface :app

      attr_accessor :request, :session

      def initialize
        super
        @session = {}
      end
    end

    setup do
      @controller = TestController.new
    end

    test "ceremony state helpers remain private" do
      %i(
        passkey_challenge_store
        passkey_actor_global_key
        passkey_actor_id_from
        issue_passkey_registration_challenge
        issue_passkey_authentication_challenge
        consume_passkey_challenge!
        consume_passkey_challenge_with_actor!
        discard_passkey_challenge
        webauthn_credential_ids
        passkey_resource_display_name
      ).each do |method_name|
        assert_includes @controller.private_methods, method_name
        assert_not_includes @controller.public_methods, method_name
      end
    end

    test "declared surface and relying-party configuration are public" do
      assert_equal :app, @controller.webauthn_surface.key
      assert_respond_to @controller, :webauthn_relying_party_config
      assert_not_includes @controller.private_methods, :webauthn_surface
      assert_not_includes @controller.private_methods, :webauthn_relying_party_config
    end

    test "actor global keys are scoped and reversible" do
      actor = Struct.new(:id).new(12_345)

      key = @controller.send(:passkey_actor_global_key, actor)

      assert_equal "app:12345", key
      assert_equal 12_345, @controller.send(:passkey_actor_id_from, key)
      assert_nil @controller.send(:passkey_actor_id_from, "com:12345")
      assert_nil @controller.send(:passkey_actor_global_key, nil)
    end

    test "credential ids accepts records and hashes" do
      record = Struct.new(:webauthn_id).new("record-id")

      assert_equal ["record-id", "hash-id"],
                   @controller.send(:webauthn_credential_ids, [record, { id: "hash-id" }])
    end

    test "resource display name falls back to the resource id" do
      resource = Struct.new(:id).new(42)

      assert_equal "42", @controller.send(:passkey_resource_display_name, resource)
    end
  end
end

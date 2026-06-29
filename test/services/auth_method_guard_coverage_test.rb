# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class AuthMethodGuardCoverageTest < ActiveSupport::TestCase
  Scope =
    Struct.new(:count_value, :not_calls) do
      def initialize(...)
        super
        self.not_calls ||= []
      end

      def where(*_args)
        self
      end

      def not(**kwargs)
        not_calls << kwargs
        self.count_value = [count_value - 1, 0].max if count_value.to_i > 0
        self
      end

      def count
        count_value
      end
    end

  class ClientActor
    def initialize(email_scope:, telephone_scope:, passkey_scope:, google:, apple:)
      @email_scope = email_scope
      @telephone_scope = telephone_scope
      @passkey_scope = passkey_scope
      @google = google
      @apple = apple
    end

    def client_emails = @email_scope

    def client_telephones = @telephone_scope

    def client_passkeys = @passkey_scope

    def user_google_identity = @google

    def user_apple_identity = @apple
  end

  class VisitorActor
    def initialize(email_scope:, telephone_scope:, passkey_scope:)
      @email_scope = email_scope
      @telephone_scope = telephone_scope
      @passkey_scope = passkey_scope
    end

    def visitor_emails = @email_scope

    def visitor_telephones = @telephone_scope

    def visitor_passkeys = @passkey_scope
  end

  Inventory =
    Struct.new(:aal1_method_count, :retains_aal1_value, :retains_aal2_value, :retains_contactability_value) do
      def retains_aal1? = retains_aal1_value

      def retains_aal2? = retains_aal2_value

      def retains_contactability? = retains_contactability_value
    end

  test "verified counts cover client, visitor, and fallback branches" do
    client_scope = Scope.new(2, [])
    visitor_scope = Scope.new(3, [])
    telephone_scope = Scope.new(1, [])
    passkey_scope = Scope.new(4, [])

    client_actor =
      ClientActor.new(
        email_scope: client_scope,
        telephone_scope: telephone_scope,
        passkey_scope: passkey_scope,
        google: Struct.new(:status_id).new(ClientGoogleIdentityStatus::ACTIVE),
        apple: nil,
      )
    apple_only_actor =
      ClientActor.new(
        email_scope: Scope.new(0, []),
        telephone_scope: Scope.new(0, []),
        passkey_scope: Scope.new(0, []),
        google: nil,
        apple: Struct.new(:status_id).new(ClientAppleIdentityStatus::ACTIVE),
      )
    visitor_actor =
      VisitorActor.new(
        email_scope: visitor_scope,
        telephone_scope: Scope.new(2, []),
        passkey_scope: Scope.new(1, []),
      )

    assert_equal 2, AuthMethodGuard.send(:verified_emails_count, client_actor)
    assert_equal 1, AuthMethodGuard.send(:verified_emails_count, client_actor, excluding: ClientEmail.new(id: 11))
    assert_equal 3, AuthMethodGuard.send(:verified_emails_count, visitor_actor)
    assert_equal 0, AuthMethodGuard.send(:verified_emails_count, Object.new)

    assert_equal 1, AuthMethodGuard.send(:verified_telephones_count, client_actor)
    assert_equal 2, AuthMethodGuard.send(:verified_telephones_count, visitor_actor)
    assert_equal 0, AuthMethodGuard.send(:verified_telephones_count, Object.new)

    assert_equal 4, AuthMethodGuard.send(:active_passkeys_count, client_actor)
    assert_equal 1, AuthMethodGuard.send(:active_passkeys_count, visitor_actor)
    assert_equal 0, AuthMethodGuard.send(:active_passkeys_count, Object.new)

    assert_equal 1, AuthMethodGuard.send(:active_social_count, client_actor)
    assert_equal 1, AuthMethodGuard.send(:active_social_count, apple_only_actor)
    assert_equal 0, AuthMethodGuard.send(:active_social_count, Object.new)
    assert AuthMethodGuard.send(:excluding_record?, ClientEmail.new(id: 1), "ClientEmail")
    assert_not AuthMethodGuard.send(:excluding_record?, VisitorEmail.new(id: 1), "ClientEmail")
  end

  test "public guards delegate to the inventory with exclusions" do
    actor = Object.new
    passkey = Object.new
    email = Object.new
    telephone = Object.new
    totp = Object.new
    inventory = Inventory.new(2, true, false, true)
    calls = []

    AuthenticationCredentialInventory.stub(
      :call,
      ->(current_actor, excluding: nil, reload: nil) do
        calls << [current_actor, excluding, reload]
        inventory
      end,
    ) do
      assert_equal 2, AuthMethodGuard.remaining_count(actor)
      assert_equal 2, AuthMethodGuard.remaining_count(actor, excluding: passkey)
      assert_not AuthMethodGuard.last_method?(actor)
      assert_not AuthMethodGuard.can_remove_passkey?(actor, passkey)
      assert_not AuthMethodGuard.can_remove_email?(actor, email)
      assert AuthMethodGuard.can_remove_telephone?(actor, telephone)
      assert_not AuthMethodGuard.can_remove_totp?(actor, totp)
    end

    assert_equal [
      [actor, nil, true],
      [actor, passkey, true],
      [actor, nil, true],
      [actor, passkey, true],
      [actor, email, true],
      [actor, telephone, true],
      [actor, totp, true],
    ], calls
  end
end

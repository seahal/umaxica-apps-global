# frozen_string_literal: true

require "test_helper"

class WithdrawalPersonalDataAnonymizerTest < ActiveSupport::TestCase
  fixtures_none!

  AnonymizedRecord =
    Struct.new(:id, :updated_attrs, :discarded_at, :model_class) do
      def update!(attrs)
        self.updated_attrs = attrs
      end

      def class
        model_class
      end

      def is_a?(klass)
        klass == model_class || super
      end
    end

  Scope =
    Struct.new(:records) do
      def find_each(&)
        records.each(&)
      end
    end

  test "anonymizes a client actor and purges cross-database children" do
    client = Client.allocate
    purge_calls = []

    client_email = AnonymizedRecord.new(11, nil, nil, ClientEmail)
    client_telephone = AnonymizedRecord.new(12, nil, nil, ClientTelephone)
    client_passkey = AnonymizedRecord.new(13, nil, nil, ClientPasskey)
    client_secret = AnonymizedRecord.new(14, nil, nil, ClientSecretCredential)
    client_totp = AnonymizedRecord.new(15, nil, nil, ClientTotpCredential)
    google_identity = AnonymizedRecord.new(16, nil, nil, ClientGoogleIdentity)

    define_client_actor(
      client,
      emails: [client_email],
      telephones: [client_telephone],
      passkeys: [client_passkey],
      secrets: [client_secret],
      totps: [client_totp],
      google_identity: google_identity,
      apple_identity: nil,
    )

    RetentionCrossDatabaseChildPurge.stub(:call, ->(actor:) { purge_calls << actor }) do
      result = WithdrawalPersonalDataAnonymizer.call(actor: client)

      assert_same client, result
    end

    assert_equal [client], purge_calls
    assert_equal "withdrawn-client-email-11@anonymous.invalid", client_email.updated_attrs.fetch(:address)
    assert_nil client_email.updated_attrs.fetch(:address_digest)
    assert_equal "withdrawn", client_email.updated_attrs.fetch(:otp_private_key)
    assert_equal "0", client_email.updated_attrs.fetch(:otp_counter)
    assert_equal ClientEmailStatus::SUSPENDED, client_email.updated_attrs.fetch(:user_email_status_id)

    assert_equal "+100000000000012", client_telephone.updated_attrs.fetch(:number)
    assert_nil client_telephone.updated_attrs.fetch(:number_digest)
    assert_equal "withdrawn", client_telephone.updated_attrs.fetch(:otp_private_key)
    assert_equal "0", client_telephone.updated_attrs.fetch(:otp_counter)
    assert_equal ClientTelephoneStatus::SUSPENDED,
                 client_telephone.updated_attrs.fetch(:user_identity_telephone_status_id)

    assert_equal ClientPasskeyStatus::REVOKED, client_passkey.updated_attrs.fetch(:status_id)
    assert_in_delta Time.current.to_f, client_passkey.updated_attrs.fetch(:discarded_at).to_f, 1

    assert_equal ClientSecretCredentialStatus::REVOKED, client_secret.updated_attrs.fetch(:user_secret_status_id)
    assert_in_delta Time.current.to_f, client_secret.updated_attrs.fetch(:discarded_at).to_f, 1

    assert_equal ClientTotpCredentialStatus::REVOKED,
                 client_totp.updated_attrs.fetch(:user_identity_totp_credential_status_id)
    assert_in_delta Time.current.to_f, client_totp.updated_attrs.fetch(:discarded_at).to_f, 1

    assert_equal "withdrawn-client-google-identity-16", google_identity.updated_attrs.fetch(:uid)
    assert_equal "withdrawn", google_identity.updated_attrs.fetch(:token)
    assert_equal ClientGoogleIdentityStatus::REVOKED, google_identity.updated_attrs.fetch(:status_id)
  end

  test "anonymizes a visitor actor" do
    visitor = Visitor.allocate
    purge_calls = []

    visitor_email = AnonymizedRecord.new(21, nil, nil, VisitorEmail)
    visitor_telephone = AnonymizedRecord.new(22, nil, nil, VisitorTelephone)
    visitor_passkey = AnonymizedRecord.new(23, nil, nil, VisitorPasskey)
    visitor_secret = AnonymizedRecord.new(24, nil, nil, VisitorSecretCredential)

    define_visitor_actor(
      visitor,
      emails: [visitor_email],
      telephones: [visitor_telephone],
      passkeys: [visitor_passkey],
      secrets: [visitor_secret],
    )

    RetentionCrossDatabaseChildPurge.stub(:call, ->(actor:) { purge_calls << actor }) do
      result = WithdrawalPersonalDataAnonymizer.call(actor: visitor)

      assert_same visitor, result
    end

    assert_equal [visitor], purge_calls
    assert_equal "withdrawn-visitor-email-21@anonymous.invalid", visitor_email.updated_attrs.fetch(:address)
    assert_equal "withdrawn", visitor_email.updated_attrs.fetch(:otp_private_key)
    assert_equal "0", visitor_email.updated_attrs.fetch(:otp_counter)
    assert_equal VisitorEmailStatus::SUSPENDED, visitor_email.updated_attrs.fetch(:visitor_email_status_id)

    assert_equal "+100000000000022", visitor_telephone.updated_attrs.fetch(:number)
    assert_equal "withdrawn", visitor_telephone.updated_attrs.fetch(:otp_private_key)
    assert_equal "0", visitor_telephone.updated_attrs.fetch(:otp_counter)
    assert_equal VisitorTelephoneStatus::SUSPENDED, visitor_telephone.updated_attrs.fetch(:visitor_telephone_status_id)

    assert_equal VisitorPasskeyStatus::REVOKED, visitor_passkey.updated_attrs.fetch(:status_id)
    assert_in_delta Time.current.to_f, visitor_passkey.updated_attrs.fetch(:discarded_at).to_f, 1

    assert_equal VisitorSecretCredentialStatus::REVOKED,
                 visitor_secret.updated_attrs.fetch(:visitor_secret_credential_status_id)
    assert_in_delta Time.current.to_f, visitor_secret.updated_attrs.fetch(:discarded_at).to_f, 1
  end

  private

  def define_client_actor(actor, emails:, telephones:, passkeys:, secrets:, totps:, google_identity:, apple_identity:)
    actor.define_singleton_method(:client_emails) { Scope.new(emails) }
    actor.define_singleton_method(:client_telephones) { Scope.new(telephones) }
    actor.define_singleton_method(:client_passkeys) { Scope.new(passkeys) }
    actor.define_singleton_method(:client_secret_credentials) { Scope.new(secrets) }
    actor.define_singleton_method(:client_totp_credentials) { Scope.new(totps) }
    actor.define_singleton_method(:user_google_identity) { google_identity }
    actor.define_singleton_method(:user_apple_identity) { apple_identity }
  end

  def define_visitor_actor(actor, emails:, telephones:, passkeys:, secrets:)
    actor.define_singleton_method(:visitor_emails) { Scope.new(emails) }
    actor.define_singleton_method(:visitor_telephones) { Scope.new(telephones) }
    actor.define_singleton_method(:visitor_passkeys) { Scope.new(passkeys) }
    actor.define_singleton_method(:visitor_secret_credentials) { Scope.new(secrets) }
  end
end

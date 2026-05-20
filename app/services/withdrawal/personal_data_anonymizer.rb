# typed: false
# frozen_string_literal: true

module Withdrawal
  class PersonalDataAnonymizer
    def self.call(actor:)
      new(actor:).call
    end

    def initialize(actor:)
      @actor = actor
    end

    def call
      anonymize_client if actor.is_a?(Client)
      anonymize_visitor if actor.is_a?(Visitor)
      # Explicit, ordered cleanup of non-audit children that live in other
      # databases (no implicit cross-DB AR cascade). Chronicle/audit is
      # intentionally retained.
      Retention::CrossDatabaseChildPurge.call(actor: actor)
      actor
    end

    private

    attr_reader :actor

    def anonymize_client
      anonymize_emails(actor.client_emails, status_column: :user_email_status_id)
      anonymize_telephones(actor.client_telephones, status_column: :user_identity_telephone_status_id)
      revoke_records(actor.client_passkeys, status_column: :status_id, revoked_status: ClientPasskeyStatus::REVOKED)
      revoke_records(actor.client_secrets, status_column: :user_secret_status_id, revoked_status: ClientSecretStatus::REVOKED)
      revoke_records(
        actor.client_one_time_passwords, status_column: :user_identity_one_time_password_status_id,
                                         revoked_status: ClientOneTimePasswordStatus::REVOKED,
      )
      anonymize_social(actor.user_social_google, revoked_status: ClientSocialGoogleStatus::REVOKED)
      anonymize_social(actor.user_social_apple, revoked_status: ClientSocialAppleStatus::REVOKED)
    end

    def anonymize_visitor
      anonymize_emails(actor.visitor_emails, status_column: :visitor_email_status_id)
      anonymize_telephones(actor.visitor_telephones, status_column: :visitor_telephone_status_id)
      revoke_records(actor.visitor_passkeys, status_column: :status_id, revoked_status: VisitorPasskeyStatus::REVOKED)
      revoke_records(actor.visitor_secrets, status_column: :visitor_secret_status_id, revoked_status: VisitorSecretStatus::REVOKED)
    end

    def anonymize_emails(scope, status_column:)
      scope.find_each do |email|
        email.update!(
          :address => "withdrawn-#{email.class.name.underscore.dasherize}-#{email.id}@anonymous.invalid",
          :address_digest => nil,
          :otp_private_key => "",
          :otp_counter => "",
          :otp_attempts_count => 0,
          :otp_expires_at => -Float::INFINITY,
          :locked_at => -Float::INFINITY,
          status_column => revoked_or_suspended_email_status(email),
        )
      end
    end

    def anonymize_telephones(scope, status_column:)
      scope.find_each do |telephone|
        telephone.update!(
          :number => "+100000#{telephone.id.to_s.rjust(9, "0")}",
          :number_digest => nil,
          :otp_private_key => "",
          :otp_counter => "",
          :otp_attempts_count => 0,
          :otp_expires_at => -Float::INFINITY,
          :locked_at => -Float::INFINITY,
          status_column => revoked_or_suspended_telephone_status(telephone),
        )
      end
    end

    def revoke_records(scope, status_column:, revoked_status:)
      scope.find_each do |record|
        attrs = { status_column => revoked_status }
        attrs[:discarded_at] = Time.current if record.respond_to?(:discarded_at=)
        record.update!(attrs)
      end
    end

    def anonymize_social(record, revoked_status:)
      return unless record

      record.update!(
        uid: "withdrawn-#{record.class.name.underscore.dasherize}-#{record.id}",
        token: "withdrawn",
        refresh_token: "",
        status_id: revoked_status,
      )
    end

    def revoked_or_suspended_email_status(email)
      if email.is_a?(ClientEmail)
        ClientEmailStatus::SUSPENDED
      else
        VisitorEmailStatus::SUSPENDED
      end
    end

    def revoked_or_suspended_telephone_status(telephone)
      if telephone.is_a?(ClientTelephone)
        ClientTelephoneStatus::SUSPENDED
      else
        VisitorTelephoneStatus::SUSPENDED
      end
    end
  end
end

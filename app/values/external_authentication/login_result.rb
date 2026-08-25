# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  class LoginResult < Data.define(:status, :user, :identity, :existing_account)
    STATUSES = %i(authenticated signup_required).freeze

    def initialize(status:, user:, identity:, existing_account:)
      raise ArgumentError, "status is unsupported" unless STATUSES.include?(status)

      case status
      when :authenticated
        raise ArgumentError, "authenticated result requires user and identity" if user.nil? || identity.nil?
        raise ArgumentError, "authenticated result must be an existing account" unless existing_account == true
      when :signup_required
        unless user.nil? && identity.nil? && existing_account == false
          raise ArgumentError, "signup required result cannot contain an account"
        end
      end

      super
    end

    def authenticated? = status == :authenticated

    def signup_required? = status == :signup_required
  end
end

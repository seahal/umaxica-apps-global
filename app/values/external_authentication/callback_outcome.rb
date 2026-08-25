# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  class CallbackOutcome < Data.define(
    :status,
    :user,
    :identity,
    :existing_account,
    :pt,
    :entry,
  )
    STATUSES = %i(authenticated signup_required link_completed).freeze

    def initialize(status:, user:, identity:, existing_account:, pt: nil, entry: nil)
      raise ArgumentError, "status is unsupported" unless STATUSES.include?(status)

      case status
      when :authenticated
        raise ArgumentError, "authenticated outcome requires user and identity" if user.nil? || identity.nil?
        raise ArgumentError, "authenticated outcome requires an existing account" unless existing_account == true
      when :signup_required
        unless user.nil? && identity.nil? && existing_account == false
          raise ArgumentError, "signup required outcome cannot contain an account"
        end
      when :link_completed
        raise ArgumentError, "link outcome requires user and identity" if user.nil? || identity.nil?
        raise ArgumentError, "link outcome has no account classification" unless existing_account.nil?
      end

      super
    end

    def authenticated? = status == :authenticated

    def signup_required? = status == :signup_required

    def link_completed? = status == :link_completed
  end
end

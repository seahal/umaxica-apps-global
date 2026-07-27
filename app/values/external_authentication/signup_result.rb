# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  class SignupResult < Data.define(:status, :user, :identity)
    def initialize(status:, user:, identity:)
      raise ArgumentError, "status is unsupported" unless status == :created
      raise ArgumentError, "created result requires user and identity" if user.nil? || identity.nil?

      super
    end

    def created? = status == :created
  end
end

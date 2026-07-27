# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  class LinkResult < Data.define(:status, :user, :identity)
    def initialize(status:, user:, identity:)
      raise ArgumentError, "status is unsupported" unless status == :linked
      raise ArgumentError, "linked result requires user and identity" if user.nil? || identity.nil?

      super
    end

    def linked? = status == :linked
  end
end

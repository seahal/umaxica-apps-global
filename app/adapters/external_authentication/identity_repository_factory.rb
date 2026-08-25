# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  class IdentityRepositoryFactory
    def self.current
      new
    end

    def build(provider)
      ClientExternalIdentityRepositoryAdapter.new(provider: provider)
    end
  end
end

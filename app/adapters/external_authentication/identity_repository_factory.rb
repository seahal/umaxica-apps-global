# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  class IdentityRepositoryFactory
    STORAGE_MODES = %i(legacy common).freeze
    CURRENT_STORAGE = :legacy

    def self.current
      new(storage: CURRENT_STORAGE)
    end

    def self.common_storage?
      CURRENT_STORAGE == :common
    end

    def self.legacy
      new(storage: :legacy)
    end

    def self.common
      new(storage: :common)
    end

    def initialize(storage:)
      raise ArgumentError, "storage is unsupported" unless STORAGE_MODES.include?(storage)

      @storage = storage
    end

    def build(provider)
      case storage
      when :legacy then LegacyIdentityRepositoryFactory.build(provider)
      when :common then ClientExternalIdentityRepositoryAdapter.new(provider: provider)
      end
    end

    private

    attr_reader :storage
  end
end

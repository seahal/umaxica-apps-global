# typed: false
# frozen_string_literal: true

OrgEntraIdentityResolution =
  Data.define(:status, :identity, :operator, :error) do
    def self.resolved(identity:, operator:)
      new(status: :resolved, identity: identity, operator: operator, error: nil)
    end

    def self.rejected(error:, identity: nil)
      new(status: :rejected, identity: identity, operator: nil, error: error.to_s)
    end

    def resolved? = status == :resolved

    def rejected? = status == :rejected
  end

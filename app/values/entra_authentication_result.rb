# typed: false
# frozen_string_literal: true

EntraAuthenticationResult =
  Data.define(:status, :tenant_id, :entra_object_id, :evidence_issuer, :evidence_subject, :error) do
    def self.verified(tenant_id:, entra_object_id:, evidence_issuer:, evidence_subject:)
      new(
        status: :verified,
        tenant_id: tenant_id,
        entra_object_id: entra_object_id,
        evidence_issuer: evidence_issuer,
        evidence_subject: evidence_subject,
        error: nil,
      )
    end

    def self.rejected(error:)
      new(
        status: :rejected,
        tenant_id: nil,
        entra_object_id: nil,
        evidence_issuer: nil,
        evidence_subject: nil,
        error: error.to_s,
      )
    end

    def verified? = status == :verified

    def rejected? = status == :rejected
  end

# typed: false
# frozen_string_literal: true

module ExternalSignIn
  # Verified, normalized claims from an external identity provider token.
  # tenant_id and object_id are the stable (tid, oid) lookup key for Entra ID.
  # evidence_issuer and evidence_subject store iss/sub for audit only; never used for auth lookup.
  # entra_object_id is the stable oid claim. Named with prefix to avoid collision with Object#object_id.
  NormalizedAuthResult = Data.define(:tenant_id, :entra_object_id, :evidence_issuer, :evidence_subject)
end

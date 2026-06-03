# typed: false
# frozen_string_literal: true

# Acme/org durable one-shot storage for secret credential enrollment results.
class OperatorSecretCredentialCeremonyTransaction < OrgTicketRecord
  include SecretCredentialCeremonyTransactionable

  ceremony_surface "org"
end

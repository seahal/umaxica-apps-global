# typed: false
# frozen_string_literal: true

# Acme/com durable one-shot storage for secret credential enrollment results.
class VisitorSecretCredentialCeremonyTransaction < ComTicketRecord
  include SecretCredentialCeremonyTransactionable

  ceremony_surface "com"
end

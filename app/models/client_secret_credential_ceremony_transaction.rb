# typed: false
# frozen_string_literal: true

# Acme/app durable one-shot storage for secret credential enrollment results.
class ClientSecretCredentialCeremonyTransaction < AppTicketRecord
  include SecretCredentialCeremonyTransactionable

  ceremony_surface "app"
end

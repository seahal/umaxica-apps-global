# typed: false
# frozen_string_literal: true

# Acme/app durable one-shot storage for social link ceremony results.
class ClientSocialCeremonyTransaction < AppTicketRecord
  include SocialCeremonyTransactionable

  ceremony_surface "app"
end

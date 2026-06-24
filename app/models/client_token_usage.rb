# typed: false
# frozen_string_literal: true

class ClientTokenUsage < AppTicketRecord
  include OidcTokenUsage

  belongs_to :client_token, inverse_of: :client_token_usages

  delegate :user, to: :client_token

  private

  def parent_association_name
    :client_token
  end
end

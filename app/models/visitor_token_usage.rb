# typed: false
# frozen_string_literal: true

class VisitorTokenUsage < ComTicketRecord
  include OidcTokenUsage

  belongs_to :visitor_token, inverse_of: :visitor_token_usages

  delegate :visitor, to: :visitor_token

  private

  def parent_association_name
    :visitor_token
  end
end

# typed: false
# frozen_string_literal: true

class OperatorTokenUsage < OrgTicketRecord
  include OidcTokenUsage

  belongs_to :operator_token, inverse_of: :operator_token_usages

  delegate :staff, to: :operator_token

  private

  def parent_association_name
    :operator_token
  end
end

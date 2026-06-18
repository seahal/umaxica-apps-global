# typed: false
# frozen_string_literal: true

class IdentitySocialCeremonyCandidate < AppTicketRecord
  include IdentityCeremonyCandidateRecord

  encrypts :auth_hash

  serialize :auth_hash, coder: JSON

  validates :transaction_id, :operation, :provider, :auth_hash, presence: true
  validates :surface, inclusion: { in: IdentitySocialCeremonyContract::SURFACES }
  validates :operation, inclusion: { in: IdentitySocialCeremonyContract::OPERATIONS }
  validates :provider, inclusion: { in: IdentitySocialCeremonyContract::PROVIDERS }
  validate :auth_hash_shape

  private

  def auth_hash_shape
    return if auth_hash.is_a?(Hash) && auth_hash["provider"].present? && auth_hash["uid"].present?

    errors.add(:auth_hash, "is invalid")
  end
end

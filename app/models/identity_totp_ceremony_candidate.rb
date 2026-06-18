# typed: false
# frozen_string_literal: true

class IdentityTotpCeremonyCandidate < AppTicketRecord
  include IdentityCeremonyCandidateRecord

  encrypts :private_key

  validates :private_key, :last_otp_at, presence: true
  validates :surface, inclusion: { in: IdentityTotpCeremonyContract::SURFACES }
end

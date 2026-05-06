# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: customer_verifications
# Database name: symbol
#
#  id                :bigint           not null, primary key
#  expires_at        :datetime         not null
#  last_used_at      :datetime
#  revoked_at        :datetime
#  token_digest      :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  customer_token_id :bigint           not null
#
# Indexes
#
#  index_customer_verifications_on_customer_token_id  (customer_token_id)
#  index_customer_verifications_on_expires_at         (expires_at)
#  index_customer_verifications_on_token_digest       (token_digest) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (customer_token_id => customer_tokens.id)
#
class CustomerVerification < SymbolRecord
  include RefreshTokenShared
  include VerificationCookieable

  TTL = 15.minutes

  belongs_to :customer_token, inverse_of: :customer_verifications

  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  def active?
    revoked_at.nil? && expires_at.present? && expires_at > Time.current
  end

  def self.digest_token(raw_token)
    digest_refresh_token(raw_token.to_s).unpack1("H*")
  end

  def self.issue_for_token!(token:, expires_at: TTL.from_now)
    now = Time.current
    raw_token = SecureRandom.urlsafe_base64(32)
    digest = digest_token(raw_token)

    verification =
      transaction do
        where(customer_token_id: token.id).active.find_each do |verification_record|
          verification_record.update!(revoked_at: now, updated_at: now)
        end

        create!(
          customer_token: token,
          token_digest: digest,
          expires_at: expires_at,
          last_used_at: now,
        )
      end

    [verification, raw_token]
  end
end

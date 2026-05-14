# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_verifications
# Database name: token
#
#  id             :bigint           not null, primary key
#  lapses_at      :datetime         default(Infinity), not null
#  last_used_at   :datetime
#  purge_at       :datetime         default(Infinity), not null
#  token_digest   :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  staff_token_id :bigint           not null
#
# Indexes
#
#  index_staff_verifications_on_staff_token_id  (staff_token_id)
#  index_staff_verifications_on_token_digest    (token_digest) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (staff_token_id => staff_tokens.id) ON DELETE => cascade
#
class OperatorVerification < TokenRecord
  self.table_name = "staff_verifications"
  include Retainable
  include RefreshTokenShared
  include VerificationCookieable

  TTL = 15.minutes

  belongs_to :staff_token, class_name: "OperatorToken", inverse_of: :staff_verifications

  validates :token_digest, presence: true, uniqueness: true
  validates :lapses_at, presence: true

  scope :active, -> { where("lapses_at > ?", Time.current) }

  def active?
    lapses_at.present? && lapses_at > Time.current
  end

  def self.digest_token(raw_token)
    digest_refresh_token(raw_token.to_s).unpack1("H*")
  end

  def self.issue_for_token!(token:, lapses_at: TTL.from_now)
    now = Time.current
    raw_token = SecureRandom.urlsafe_base64(32)
    digest = digest_token(raw_token)

    verification =
      transaction do
        where(staff_token_id: token.id).active.find_each do |verification_record|
          verification_record.update!(lapses_at: now, updated_at: now)
        end

        create!(
          staff_token: token,
          token_digest: digest,
          lapses_at: lapses_at,
          last_used_at: now,
        )
      end

    [verification, raw_token]
  end
end

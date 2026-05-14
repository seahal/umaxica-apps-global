# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_telephones
# Database name: guest
#
#  id                          :bigint           not null, primary key
#  locked_at                   :datetime         default(-Infinity), not null
#  number                      :string           default(""), not null
#  number_digest               :string
#  otp_attempts_count          :integer          default(0), not null
#  otp_counter                 :text             default(""), not null
#  otp_expires_at              :datetime         default(-Infinity), not null
#  otp_private_key             :string           default(""), not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  public_id                   :string(21)       not null
#  visitor_id                  :bigint           not null
#  visitor_telephone_status_id :bigint           default(1), not null
#
# Indexes
#
#  index_visitor_telephones_on_lower_number                 (lower((number)::text)) UNIQUE
#  index_visitor_telephones_on_number_digest                (number_digest) UNIQUE WHERE (number_digest IS NOT NULL)
#  index_visitor_telephones_on_public_id                    (public_id) UNIQUE
#  index_visitor_telephones_on_visitor_id                   (visitor_id)
#  index_visitor_telephones_on_visitor_telephone_status_id  (visitor_telephone_status_id)
#
# Foreign Keys
#
#  fk_rails_...  (visitor_id => visitors.id)
#  fk_rails_...  (visitor_telephone_status_id => visitor_telephone_statuses.id)
#
class VisitorTelephone < GuestRecord
  include Telephone
  include PublicId

  self.filter_attributes += %w(number)

  # FIXME: set telephone max is 2
  MAX_TELEPHONES_PER_VISITOR = 4

  attribute :visitor_telephone_status_id, default: VisitorTelephoneStatus::UNVERIFIED

  belongs_to :visitor, inverse_of: :visitor_telephones
  belongs_to :visitor_telephone_status, optional: true, inverse_of: :visitor_telephones

  validates :otp_attempts_count, presence: true, numericality: { only_integer: true }
  validates :otp_counter, presence: true
  validates :otp_private_key, presence: true, length: { maximum: 255 }
  validates :visitor_telephone_status_id, numericality: { only_integer: true }
  validate :ensure_unique_number_digest
  validate :enforce_visitor_telephone_limit, on: :create

  def to_param
    public_id
  end

  private

  def ensure_unique_number_digest
    return if number_digest.blank?
    return unless self.class.where(number_digest: number_digest).where.not(id: id).exists?

    errors.add(:number, :taken)
  end

  def enforce_visitor_telephone_limit
    return unless visitor_id

    count = self.class.where(visitor_id: visitor_id).count
    return if count < MAX_TELEPHONES_PER_VISITOR

    errors.add(:base, :too_many, message: "exceeds maximum telephones per visitor (#{MAX_TELEPHONES_PER_VISITOR})")
  end
end

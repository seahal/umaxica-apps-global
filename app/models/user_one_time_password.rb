# typed: false
# frozen_string_literal: true

# frozen_string_literal: true

# == Schema Information
#
# Table name: user_one_time_passwords
# Database name: principal
#
#  id                                        :bigint           not null, primary key
#  last_otp_at                               :datetime         default(-Infinity), not null
#  private_key                               :string(1024)     default(""), not null
#  title                                     :string(32)
#  created_at                                :datetime         not null
#  updated_at                                :datetime         not null
#  public_id                                 :string(21)       not null
#  user_id                                   :bigint           not null
#  user_identity_one_time_password_status_id :bigint           default(5), not null
#
# Indexes
#
#  idx_on_user_identity_one_time_password_status_id_c03cdf0b39  (user_identity_one_time_password_status_id)
#  index_user_one_time_passwords_on_public_id                   (public_id) UNIQUE
#  index_user_one_time_passwords_on_user_id                     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#  fk_rails_...  (user_identity_one_time_password_status_id => user_one_time_password_statuses.id)
#

class UserOneTimePassword < PrincipalRecord
  include ::PublicId
  include MultiFactorStatusCredential

  alias_attribute :user_one_time_password_status_id, :user_identity_one_time_password_status_id
  MAX_TOTPS_PER_USER = 2

  attr_accessor :first_token

  belongs_to :user, inverse_of: :user_one_time_passwords
  multi_factor_status_owner :user
  belongs_to :user_one_time_password_status, optional: true, inverse_of: :user_one_time_passwords,
                                             foreign_key: :user_identity_one_time_password_status_id
  attribute :user_identity_one_time_password_status_id, default: UserOneTimePasswordStatus::NOTHING

  validates :private_key, presence: true, length: { maximum: 1024 }
  validates :last_otp_at, presence: true
  validates :title, length: { maximum: 32 }, allow_blank: true
  validate :enforce_user_totp_limit, on: :create

  after_initialize :generate_private_key_if_blank
  after_initialize :generate_public_id_if_blank

  private

  def generate_public_id_if_blank
    return unless has_attribute?(:public_id)

    self.public_id = Nanoid.generate(size: 21) if self[:public_id].blank?
  end

  def enforce_user_totp_limit
    return unless user_id

    operation = -> { self.class.where(user_id: user_id).count }
    count = defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
    return if count < MAX_TOTPS_PER_USER

    errors.add(:base, :too_many, message: "exceeds maximum totps per user (#{MAX_TOTPS_PER_USER})")
  end

  def generate_private_key_if_blank
    self.private_key = ROTP::Base32.random_base32 if private_key.blank?
  end
end

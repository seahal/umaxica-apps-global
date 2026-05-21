# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_social_googles
# Database name: org_principal
#
#  id                    :bigint           not null, primary key
#  last_authenticated_at :datetime
#  provider              :string           default("google_org"), not null
#  refresh_token         :string           default(""), not null
#  token                 :string           default(""), not null
#  token_expires_at      :integer          not null
#  uid                   :string           default(""), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  staff_id              :bigint           not null
#  status_id             :bigint           default(1), not null
#
# Indexes
#
#  index_operator_social_googles_on_staff_id_unique   (staff_id) UNIQUE WHERE (staff_id IS NOT NULL)
#  index_operator_social_googles_on_status_id         (status_id)
#  index_operator_social_googles_on_token_expires_at  (token_expires_at)
#  index_operator_social_googles_on_uid_and_provider  (uid,provider) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (staff_id => operators.id)
#  fk_rails_...  (status_id => operator_social_google_statuses.id)
#
class OperatorSocialGoogle < OrgPrincipalRecord
  include SocialIdentifiable

  alias_attribute :expires_at, :token_expires_at
  attribute :status_id, default: OperatorSocialGoogleStatus::ACTIVE

  belongs_to :staff, class_name: "Operator", inverse_of: :operator_social_google
  belongs_to :operator_social_google_status,
             class_name: "OperatorSocialGoogleStatus",
             inverse_of: :operator_social_googles,
             foreign_key: :status_id

  validates :token, presence: true
  validates :staff_id, uniqueness: { conditions: -> { where.not(staff_id: nil) } }
  validates :uid, presence: true, uniqueness: { scope: :provider }
  validates :token_expires_at, presence: true
  validates :status_id, numericality: { only_integer: true }

  before_validation :ensure_status_defaults, on: :create

  def self.status_column
    :status_id
  end

  def self.status_class
    OperatorSocialGoogleStatus
  end

  private

  def ensure_status_defaults
    OperatorSocialGoogleStatus.ensure_defaults!
  end
end

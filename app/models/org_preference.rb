# typed: false
# == Schema Information
#
# Table name: org_preferences
# Database name: org_setting
#
#  id                       :bigint           not null, primary key
#  dbsc_challenge           :text
#  dbsc_challenge_issued_at :datetime
#  dbsc_public_key          :jsonb
#  device_id_digest         :string
#  discarded_at             :datetime         default(Infinity), not null
#  jti                      :string
#  purged_at                :datetime         default(Infinity), not null
#  token_digest             :binary
#  used_at                  :datetime
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  binding_method_id        :bigint           default(0), not null
#  dbsc_session_id          :string
#  dbsc_status_id           :bigint           default(0), not null
#  device_id                :string
#  public_id                :string           not null
#  replaced_by_id           :bigint
#  status_id                :bigint           default(2), not null
#
# Indexes
#
#  index_org_preferences_on_binding_method_id  (binding_method_id)
#  index_org_preferences_on_dbsc_session_id    (dbsc_session_id) UNIQUE
#  index_org_preferences_on_dbsc_status_id     (dbsc_status_id)
#  index_org_preferences_on_device_id          (device_id)
#  index_org_preferences_on_device_id_digest   (device_id_digest)
#  index_org_preferences_on_jti                (jti) UNIQUE
#  index_org_preferences_on_public_id          (public_id) UNIQUE
#  index_org_preferences_on_purged_at          (purged_at)
#  index_org_preferences_on_replaced_by_id     (replaced_by_id)
#  index_org_preferences_on_status_id          (status_id)
#  index_org_preferences_on_token_digest       (token_digest)
#  index_org_preferences_on_used_at            (used_at)
#
# Foreign Keys
#
#  fk_org_preferences_on_binding_method_id  (binding_method_id => org_preference_binding_methods.id)
#  fk_org_preferences_on_dbsc_status_id     (dbsc_status_id => org_preference_dbsc_statuses.id)
#  fk_org_preferences_on_status_id          (status_id => org_preference_statuses.id)
#  fk_rails_...                             (replaced_by_id => org_preferences.id) ON DELETE => nullify
#

# frozen_string_literal: true

class OrgPreference < OrgSettingRecord
  include Retainable
  include ::PublicId
  include ::SingleUseToken
  include ::Preference::Resettable
  include ::DbscBindable

  self.belongs_to_required_by_default = false

  alias_attribute :expires_at, :discarded_at

  DBSC_BINDING_METHOD_CLASS = OrgPreferenceBindingMethod
  DBSC_STATUS_CLASS = OrgPreferenceDbscStatus

  attribute :status_id, default: OrgPreferenceStatus::NOTHING
  attribute :binding_method_id, default: OrgPreferenceBindingMethod::NOTHING
  attribute :dbsc_status_id, default: OrgPreferenceDbscStatus::NOTHING

  belongs_to :org_preference_status,
             foreign_key: :status_id,
             inverse_of: :org_preferences
  belongs_to :org_preference_dbsc_status,
             foreign_key: :dbsc_status_id,
             inverse_of: :org_preferences
  # waht is this?
  belongs_to :org_preference_binding_method,
             foreign_key: :binding_method_id,
             inverse_of: :org_preferences
  # waht is this?
  belongs_to :replaced_by,
             class_name: "OrgPreference"

  has_one :org_preference_cookie,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :org_preference_region,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :org_preference_timezone,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :org_preference_language,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :org_preference_theme,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :org_preference_colortheme,
          class_name: "OrgPreferenceTheme",
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_many :org_preference_chronicles,
           foreign_key: :subject_id,
           inverse_of: :org_preference,
           dependent: :destroy
  has_many :replacements,
           class_name: "OrgPreference",
           foreign_key: :replaced_by_id,
           inverse_of: :replaced_by,
           dependent: :nullify

  validates :status_id, numericality: { only_integer: true }
  validates :jti, uniqueness: true, allow_nil: true

  before_validation :default_replaced_by_to_self, on: :create
  after_create :persist_self_replacement

  private

  def default_replaced_by_to_self
    self.replaced_by ||= self
  end

  def persist_self_replacement
    update_column(:replaced_by_id, id) if replaced_by_id.blank?
  end
end

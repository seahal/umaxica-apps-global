# typed: false
# == Schema Information
#
# Table name: app_preferences
# Database name: principal
#
#  id                       :bigint           not null, primary key
#  compromised_at           :datetime
#  dbsc_challenge           :text
#  dbsc_challenge_issued_at :datetime
#  dbsc_public_key          :jsonb
#  device_id_digest         :string
#  expires_at               :datetime
#  jti                      :string
#  revoked_at               :datetime
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
#  status_id                :bigint           default(0), not null
#
# Indexes
#
#  index_app_preferences_on_binding_method_id  (binding_method_id)
#  index_app_preferences_on_dbsc_session_id    (dbsc_session_id) UNIQUE
#  index_app_preferences_on_dbsc_status_id     (dbsc_status_id)
#  index_app_preferences_on_device_id          (device_id)
#  index_app_preferences_on_device_id_digest   (device_id_digest)
#  index_app_preferences_on_jti                (jti) UNIQUE
#  index_app_preferences_on_public_id          (public_id) UNIQUE
#  index_app_preferences_on_replaced_by_id     (replaced_by_id)
#  index_app_preferences_on_revoked_at         (revoked_at)
#  index_app_preferences_on_status_id          (status_id)
#  index_app_preferences_on_token_digest       (token_digest)
#  index_app_preferences_on_used_at            (used_at)
#
# Foreign Keys
#
#  fk_app_preferences_on_binding_method_id  (binding_method_id => app_preference_binding_methods.id)
#  fk_app_preferences_on_dbsc_status_id     (dbsc_status_id => app_preference_dbsc_statuses.id)
#  fk_app_preferences_on_status_id          (status_id => app_preference_statuses.id)
#  fk_rails_...                             (replaced_by_id => app_preferences.id) ON DELETE => nullify
#

# frozen_string_literal: true

class AppPreference < PrincipalRecord
  # TODO: Add `deletable_at` to AppPreference for lifecycle-based cleanup.
  include ::PublicId
  include ::ConsumeOnceToken
  include ::Preference::Resettable
  include ::DbscBindable

  DBSC_BINDING_METHOD_CLASS = AppPreferenceBindingMethod
  DBSC_STATUS_CLASS = AppPreferenceDbscStatus

  attribute :status_id, default: AppPreferenceStatus::NOTHING

  belongs_to :app_preference_status,
             foreign_key: :status_id,
             inverse_of: :app_preferences
  belongs_to :app_preference_binding_method,
             foreign_key: :binding_method_id,
             inverse_of: :app_preferences
  belongs_to :app_preference_dbsc_status,
             foreign_key: :dbsc_status_id,
             inverse_of: :app_preferences

  has_one :app_preference_cookie,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :app_preference_region,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :app_preference_timezone,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :app_preference_language,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :app_preference_colortheme,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_many :app_preference_chronicles,
           foreign_key: :subject_id,
           inverse_of: :app_preference,
           dependent: :destroy
  has_many :user_app_preferences,
           dependent: :delete_all,
           inverse_of: :app_preference
  belongs_to :replaced_by,
             class_name: "AppPreference",
             optional: true
  has_many :replacements,
           class_name: "AppPreference",
           foreign_key: :replaced_by_id,
           inverse_of: :replaced_by,
           dependent: :nullify
  validates :status_id, numericality: { only_integer: true }
  validates :jti, uniqueness: true, allow_nil: true
  attribute :binding_method_id, default: AppPreferenceBindingMethod::NOTHING
  attribute :dbsc_status_id, default: AppPreferenceDbscStatus::NOTHING
end

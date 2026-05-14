# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: users
# Database name: principal
#
#  id                     :bigint           not null, primary key
#  deactivated_at         :datetime
#  lapses_at              :datetime         default(Infinity), not null
#  last_reauth_at         :datetime
#  lock_version           :integer          default(0), not null
#  multi_factor_enabled   :boolean          default(FALSE), not null
#  purge_at               :datetime         default(Infinity), not null
#  purged_at              :datetime
#  withdrawal_started_at  :datetime
#  withdrawn_at           :datetime         default(Infinity)
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  multi_factor_id        :bigint           default(0), not null
#  multi_factor_status_id :bigint           default(5), not null
#  public_id              :string(255)      default(""), not null
#  status_id              :bigint           default(11), not null
#  visibility_id          :bigint           default(2), not null
#
# Indexes
#
#  index_users_on_deactivated_at          (deactivated_at) WHERE (deactivated_at IS NOT NULL)
#  index_users_on_multi_factor_id         (multi_factor_id)
#  index_users_on_multi_factor_status_id  (multi_factor_status_id)
#  index_users_on_public_id               (public_id) UNIQUE
#  index_users_on_purge_at                (purge_at)
#  index_users_on_purged_at               (purged_at) WHERE (purged_at IS NOT NULL)
#  index_users_on_status_id               (status_id)
#  index_users_on_visibility_id           (visibility_id)
#  index_users_on_withdrawal_started_at   (withdrawal_started_at) WHERE (withdrawal_started_at IS NOT NULL)
#  index_users_on_withdrawn_at            (withdrawn_at) WHERE (withdrawn_at IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (multi_factor_id => user_multi_factors.id)
#  fk_rails_...  (multi_factor_status_id => user_multi_factor_statuses.id)
#  fk_rails_...  (status_id => user_statuses.id)
#  fk_rails_...  (visibility_id => user_visibilities.id)
#

class User < PrincipalRecord
  include Retainable
  include ::PublicId
  include ::Identity
  include MultiFactorConfigurable
  include MultiFactorStatusTrackable

  LOGIN_BLOCKED_STATUS_IDS = [UserStatus::RESERVED].freeze
  # what is this?
  VERIFIED_RECOVERY_EMAIL_STATUS_IDS = [
    UserEmailStatus::VERIFIED,
    UserEmailStatus::VERIFIED_WITH_SIGN_UP,
  ].freeze
  VERIFIED_RECOVERY_TELEPHONE_STATUS_IDS = [
    UserTelephoneStatus::VERIFIED,
    UserTelephoneStatus::VERIFIED_WITH_SIGN_UP,
  ].freeze
  RECOVERY_IDENTITY_REQUIRED_MESSAGE = I18n.t("models.user.recovery_identity_required")

  # Legacy column scheduled for removal after passkeys table migration.
  # Remove this line as well after DROP COLUMN migration is completed.
  self.ignored_columns += ["webauthn_id"]

  attribute :status_id, default: UserStatus::NOTHING
  multi_factor_reference UserMultiFactor
  multi_factor_status_reference UserMultiFactorStatus

  belongs_to :user_status,
             foreign_key: :status_id,
             inverse_of: :users
  belongs_to :multi_factor,
             class_name: "UserMultiFactor",
             inverse_of: :users
  belongs_to :multi_factor_status,
             class_name: "UserMultiFactorStatus",
             inverse_of: :users
  belongs_to :visibility,
             class_name: "UserVisibility",
             inverse_of: :users
  has_one :user_social_apple,
          dependent: :destroy,
          inverse_of: :user
  has_one :user_social_google,
          dependent: :destroy,
          inverse_of: :user
  has_many :user_emails,
           dependent: :destroy,
           inverse_of: :user
  has_many :user_telephones,
           dependent: :destroy,
           inverse_of: :user
  has_many :user_secrets,
           dependent: :destroy,
           inverse_of: :user
  has_many :user_one_time_passwords,
           dependent: :destroy,
           inverse_of: :user
  has_many :user_passkeys,
           dependent: :destroy,
           inverse_of: :user
  has_many :active_totps,
           -> { where(user_identity_one_time_password_status_id: UserOneTimePasswordStatus::ACTIVE) },
           class_name: "UserOneTimePassword",
           dependent: :restrict_with_exception,
           inverse_of: :user

  has_many :user_chronicles,
           foreign_key: :subject_id,
           dependent: :destroy,
           inverse_of: false
  has_many :user_tokens,
           dependent: :destroy,
           inverse_of: :user
  has_many :user_memberships,
           dependent: :destroy,
           inverse_of: :user
  has_many :staff_chronicles, class_name: "OperatorChronicle", as: :actor,
                              dependent: :destroy
  has_many :user_notifications,
           dependent: :destroy,
           inverse_of: :user
  has_many :clients,
           class_name: "VisitorAccount",
           dependent: :nullify,
           inverse_of: :user
  has_many :user_banners,
           dependent: :destroy,
           inverse_of: :user
  has_many :user_members,
           dependent: :destroy,
           inverse_of: :user
  has_many :user_member_discoveries,
           class_name: "UserMemberDiscovery",
           dependent: :destroy,
           inverse_of: :user
  has_many :user_member_observations,
           class_name: "UserMemberObservation",
           dependent: :destroy,
           inverse_of: :user
  has_many :user_member_revocations,
           class_name: "UserMemberRevocation",
           dependent: :destroy,
           inverse_of: :user
  has_many :user_member_impersonations,
           class_name: "UserMemberImpersonation",
           dependent: :destroy,
           inverse_of: :user
  has_many :user_member_suspensions,
           class_name: "UserMemberSuspension",
           dependent: :destroy,
           inverse_of: :user
  has_many :user_member_deletions,
           class_name: "UserMemberDeletion",
           dependent: :destroy,
           inverse_of: :user
  has_many :members,
           through: :user_members
  has_many :owned_members,
           class_name: "Member",
           dependent: :nullify,
           inverse_of: :user
  has_many :user_bulletins, dependent: :destroy, inverse_of: :user
  has_many :user_app_preferences, dependent: :delete_all
  has_one :user_account, dependent: :destroy, inverse_of: :user
  has_one :user_preference, dependent: :destroy, inverse_of: :user
  has_many :avatar_assignments, dependent: :destroy
  has_many :assigned_avatars, through: :avatar_assignments, source: :avatar
  has_many :owned_avatars,
           -> { joins(:avatar_assignments).where(avatar_assignments: { role: "owner" }) },
           through: :avatar_assignments,
           source: :avatar
  validates :public_id, uniqueness: true, length: { maximum: 21 }
  include Retainable

  def totp_enabled?
    if user_one_time_passwords.loaded?
      user_one_time_passwords.any? { |otp| otp.user_one_time_password_status_id == UserOneTimePasswordStatus::ACTIVE }
    else
      user_one_time_passwords.exists?(user_one_time_password_status_id: UserOneTimePasswordStatus::ACTIVE)
    end
  end

  def staff?
    false
  end

  def user?
    true
  end

  # Compatibility shim for legacy pluralized callers.
  # Association remains has_one.
  def user_social_googles
    user_social_google ? [user_social_google] : []
  end

  # what is this?
  def has_verified_recovery_identity?
    has_verified_pii?
  end

  def has_verified_pii?
    verified_email? || verified_telephone?
  end

  def login_methods_remaining?(excluding_provider: nil)
    remaining_login_methods(excluding_provider: excluding_provider).any?
  end

  def remaining_login_methods(excluding_provider: nil)
    excluded = excluding_provider.present? ? SocialIdentifiable.normalize_provider(excluding_provider) : nil
    methods = []

    methods << :google if active_social_provider?("google") && excluded != "google"
    methods << :apple if active_social_provider?("apple") && excluded != "apple"
    methods << :email if verified_email?
    methods << :passkey if passkey_login_available?

    methods
  end

  def active_social_provider?(provider)
    normalized = SocialIdentifiable.normalize_provider(provider)
    case normalized
    when "google"
      user_social_google&.status_id == UserSocialGoogleStatus::ACTIVE
    when "apple"
      user_social_apple&.status_id == UserSocialAppleStatus::ACTIVE
    else
      false
    end
  end

  def verified_email?
    if user_emails.loaded?
      user_emails.any? { |e| VERIFIED_RECOVERY_EMAIL_STATUS_IDS.include?(e.user_email_status_id) }
    else
      user_emails.exists?(user_email_status_id: VERIFIED_RECOVERY_EMAIL_STATUS_IDS)
    end
  end

  def verified_telephone?
    if user_telephones.loaded?
      user_telephones.any? { |t| VERIFIED_RECOVERY_TELEPHONE_STATUS_IDS.include?(t.user_identity_telephone_status_id) }
    else
      user_telephones.exists?(user_identity_telephone_status_id: VERIFIED_RECOVERY_TELEPHONE_STATUS_IDS)
    end
  end

  def passkey_login_available?
    return false unless user_passkeys.active.exists?

    verified_telephone?
  end

  def withdrawal_started?
    withdrawal_started_at.present?
  end

  def deactivated?
    deactivated_at.present?
  end

  def withdrawal_in_progress?
    withdrawal_started? || deactivated?
  end

  private

  def configured_multi_factor_methods
    methods = []
    methods << :email_otp if user_emails.exists?(user_email_status_id: VERIFIED_RECOVERY_EMAIL_STATUS_IDS)
    methods << :passkey if user_passkeys.active.exists?
    methods << :totp if user_one_time_passwords.exists?(
      user_one_time_password_status_id: UserOneTimePasswordStatus::ACTIVE,
    )
    methods
  end
end

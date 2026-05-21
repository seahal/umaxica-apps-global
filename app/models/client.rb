# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: clients
# Database name: app_principal
#
#  id                     :bigint           not null, primary key
#  birthdate              :text
#  deactivated_at         :datetime
#  deletable_at           :datetime         default(Infinity), not null
#  discarded_at           :datetime         default(Infinity), not null
#  last_step_up_at        :datetime
#  lock_version           :integer          default(0), not null
#  multi_factor_enabled   :boolean          default(FALSE), not null
#  purged_at              :datetime         default(Infinity), not null
#  terminated_at          :datetime
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
#  index_clients_on_deactivated_at          (deactivated_at) WHERE (deactivated_at IS NOT NULL)
#  index_clients_on_deletable_at            (deletable_at)
#  index_clients_on_discarded_at            (discarded_at)
#  index_clients_on_multi_factor_id         (multi_factor_id)
#  index_clients_on_multi_factor_status_id  (multi_factor_status_id)
#  index_clients_on_public_id               (public_id) UNIQUE
#  index_clients_on_purged_at               (purged_at) WHERE (purged_at IS NOT NULL)
#  index_clients_on_status_id               (status_id)
#  index_clients_on_terminated_at           (terminated_at) WHERE (terminated_at IS NOT NULL)
#  index_clients_on_visibility_id           (visibility_id)
#  index_clients_on_withdrawal_started_at   (withdrawal_started_at) WHERE (withdrawal_started_at IS NOT NULL)
#  index_clients_on_withdrawn_at            (withdrawn_at) WHERE (withdrawn_at IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (multi_factor_id => client_multi_factors.id)
#  fk_rails_...  (multi_factor_status_id => client_multi_factor_statuses.id)
#  fk_rails_...  (status_id => client_statuses.id)
#  fk_rails_...  (visibility_id => client_visibilities.id)
#

class Client < AppPrincipalRecord
  # rubocop:disable Rails/HasManyOrHasOneDependent

  include Retainable
  include HasBirthdate
  include ::PublicId
  include ::Identity
  include Authentication::CredentialInventoryOwner
  include MultiFactorConfigurable
  include MultiFactorStatusTrackable

  LOGIN_BLOCKED_STATUS_IDS = [ClientStatus::RESERVED].freeze
  # what is this?
  VERIFIED_RECOVERY_EMAIL_STATUS_IDS = [
    ClientEmailStatus::VERIFIED,
    ClientEmailStatus::VERIFIED_WITH_SIGN_UP,
  ].freeze
  VERIFIED_RECOVERY_TELEPHONE_STATUS_IDS = [
    ClientTelephoneStatus::VERIFIED,
    ClientTelephoneStatus::VERIFIED_WITH_SIGN_UP,
  ].freeze
  RECOVERY_IDENTITY_REQUIRED_MESSAGE = I18n.t("models.user.recovery_identity_required")

  # Legacy column scheduled for removal after passkeys table migration.
  # Remove this line as well after DROP COLUMN migration is completed.
  self.ignored_columns += ["webauthn_id"]

  attribute :status_id, default: ClientStatus::NOTHING
  multi_factor_reference ClientMultiFactor
  multi_factor_status_reference ClientMultiFactorStatus

  belongs_to :user_status, class_name: "ClientStatus",
                           foreign_key: :status_id,
                           inverse_of: :users
  belongs_to :multi_factor,
             class_name: "ClientMultiFactor",
             inverse_of: :users
  belongs_to :multi_factor_status,
             class_name: "ClientMultiFactorStatus",
             inverse_of: :users
  belongs_to :visibility,
             class_name: "ClientVisibility",
             inverse_of: :users
  has_one :user_social_apple, class_name: "ClientSocialApple",
                              foreign_key: :user_id,
                              dependent: :destroy,
                              inverse_of: :user
  has_one :user_social_google, class_name: "ClientSocialGoogle",
                               foreign_key: :user_id,
                               dependent: :destroy,
                               inverse_of: :user
  has_many :client_emails,
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_telephones,
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_secrets,
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_one_time_passwords,
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_passkeys,
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_withdrawal_cycles,
           dependent: :restrict_with_error,
           inverse_of: :client
  has_many :active_totps,
           -> { where(user_identity_one_time_password_status_id: ClientOneTimePasswordStatus::ACTIVE) },
           class_name: "ClientOneTimePassword",
           dependent: :restrict_with_exception,
           inverse_of: :user

  # Cross-database (chronicle DB): append-only audit history. No dependent:
  # cascade — audit records intentionally outlive actor purge and are not
  # deleted across the DB boundary. See adr/chronicle-audit-db-consolidation.md.
  has_many :client_chronicles,
           foreign_key: :subject_id,
           inverse_of: false
  has_many :client_tokens,
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_device_sessions,
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :oidc_connections,
           class_name: "ClientOidcConnection",
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_memberships,
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  # Cross-database (chronicle DB), polymorphic audit history. No dependent:
  # cascade — see client_chronicles above.
  has_many :staff_chronicles, class_name: "OperatorChronicle", as: :actor
  # Cross-database (app_signal DB). Lifecycle is NOT an implicit AR cascade
  # across the DB boundary; purged explicitly via
  # Retention::CrossDatabaseChildPurge from the account purge path.
  has_many :notification_records,
           class_name: "ClientNotificationRecord",
           foreign_key: :user_id,
           inverse_of: :client
  has_many :clients,
           class_name: "ClientProfile",
           foreign_key: :user_id,
           dependent: :nullify,
           inverse_of: false
  has_many :client_banners,
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_members,
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_member_discoveries,
           class_name: "ClientMemberDiscovery",
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_member_observations,
           class_name: "ClientMemberObservation",
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_member_revocations,
           class_name: "ClientMemberRevocation",
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_member_impersonations,
           class_name: "ClientMemberImpersonation",
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_member_suspensions,
           class_name: "ClientMemberSuspension",
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :client_member_deletions,
           class_name: "ClientMemberDeletion",
           foreign_key: :user_id,
           dependent: :destroy,
           inverse_of: :user
  has_many :members,
           through: :client_members
  has_many :owned_members,
           class_name: "Member",
           foreign_key: :user_id,
           dependent: :nullify,
           inverse_of: :user
  has_many :client_bulletins, foreign_key: :user_id, dependent: :destroy, inverse_of: :user
  has_one :rp_account, class_name: "ClientAccount", foreign_key: :user_id, dependent: :destroy, inverse_of: :user
  has_one :user_preference, class_name: "ClientPreference", foreign_key: :user_id, dependent: :destroy,
                            inverse_of: :user
  # Cross-database (avatar DB). Join rows are purged explicitly via
  # Retention::CrossDatabaseChildPurge, not by an implicit cross-DB cascade.
  has_many :avatar_assignments, foreign_key: :user_id, inverse_of: :user
  has_many :assigned_avatars, through: :avatar_assignments, source: :avatar
  has_many :owned_avatars,
           -> { joins(:avatar_assignments).where(avatar_assignments: { role: "owner" }) },
           through: :avatar_assignments,
           source: :avatar
  validates :public_id, uniqueness: true, length: { maximum: 21 }
  include Retainable

  def totp_enabled?
    if client_one_time_passwords.loaded?
      client_one_time_passwords.any? { |otp| otp.user_one_time_password_status_id == ClientOneTimePasswordStatus::ACTIVE }
    else
      client_one_time_passwords.exists?(user_one_time_password_status_id: ClientOneTimePasswordStatus::ACTIVE)
    end
  end

  def staff?
    false
  end

  def user?
    true
  end

  def client?
    true
  end

  # Compatibility shim for legacy pluralized callers.
  # Association remains has_one.
  def client_social_googles
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

  def social_unlink_methods_remaining?(excluding_provider:)
    remaining_social_unlink_methods(excluding_provider: excluding_provider).any?
  end

  def remaining_social_unlink_methods(excluding_provider:)
    excluded = SocialIdentifiable.normalize_provider(excluding_provider)
    methods = []
    methods << :email if client_emails.exists?(user_email_status_id: AuthMethodGuard::VERIFIED_EMAIL_STATUSES)
    methods << :passkey if client_passkeys.exists?(status_id: ClientPasskeyStatus::ACTIVE)
    methods << :google if excluded != "google" && active_social_google_exists?
    methods << :apple if excluded != "apple" && active_social_apple_exists?
    methods
  end

  def remaining_login_methods(excluding_provider: nil)
    excluded = excluding_provider.present? ? SocialIdentifiable.normalize_provider(excluding_provider) : nil
    methods = authentication_credential_inventory.aal1_methods.map { |method| (method == :email_otp) ? :email : method }
    return methods unless excluded

    methods - [excluded.to_sym]
  end

  def active_social_provider?(provider)
    normalized = SocialIdentifiable.normalize_provider(provider)
    case normalized
    when "google"
      user_social_google&.status_id == ClientSocialGoogleStatus::ACTIVE
    when "apple"
      user_social_apple&.status_id == ClientSocialAppleStatus::ACTIVE
    else
      false
    end
  end

  def active_social_google_exists?
    ClientSocialGoogle.exists?(user_id: id, status_id: ClientSocialGoogleStatus::ACTIVE)
  end

  def active_social_apple_exists?
    ClientSocialApple.exists?(user_id: id, status_id: ClientSocialAppleStatus::ACTIVE)
  end

  def verified_email?
    return client_emails.any? { |e|
      VERIFIED_RECOVERY_EMAIL_STATUS_IDS.include?(e.user_email_status_id)
    } if client_emails.loaded?

    client_emails.exists?(user_email_status_id: VERIFIED_RECOVERY_EMAIL_STATUS_IDS)
  end

  def verified_telephone?
    return client_telephones.any? { |t|
      VERIFIED_RECOVERY_TELEPHONE_STATUS_IDS.include?(t.user_identity_telephone_status_id)
    } if client_telephones.loaded?

    client_telephones.exists?(user_identity_telephone_status_id: VERIFIED_RECOVERY_TELEPHONE_STATUS_IDS)
  end

  def passkey_login_available?
    has_active_passkey =
      if client_passkeys.loaded?
        client_passkeys.any? { |passkey| passkey.status_id == ClientPasskeyStatus::ACTIVE }
      else
        client_passkeys.active.exists?
      end
    return false unless has_active_passkey

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
    step_up_methods
  end
end

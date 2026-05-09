# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: customers
# Database name: guest
#
#  id                    :bigint           not null, primary key
#  deactivated_at        :datetime
#  lapses_at             :datetime         default(Infinity), not null
#  lock_version          :integer          default(0), not null
#  multi_factor_enabled  :boolean          default(FALSE), not null
#  purge_at              :datetime         default(Infinity), not null
#  withdrawal_started_at :datetime
#  withdrawn_at          :datetime         default(Infinity)
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  public_id             :string           default(""), not null
#  status_id             :bigint           default(2), not null
#  visibility_id         :bigint           default(1), not null
#
# Indexes
#
#  index_customers_on_deactivated_at         (deactivated_at) WHERE (deactivated_at IS NOT NULL)
#  index_customers_on_public_id              (public_id) UNIQUE
#  index_customers_on_purge_at               (purge_at)
#  index_customers_on_status_id              (status_id)
#  index_customers_on_visibility_id          (visibility_id)
#  index_customers_on_withdrawal_started_at  (withdrawal_started_at) WHERE (withdrawal_started_at IS NOT NULL)
#  index_customers_on_withdrawn_at           (withdrawn_at) WHERE (withdrawn_at IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => customer_statuses.id)
#  fk_rails_...  (visibility_id => customer_visibilities.id)
#

class Customer < GuestRecord
  include Retainable
  include ::PublicId
  include ::Identity

  LOGIN_BLOCKED_STATUS_IDS = [CustomerStatus::RESERVED].freeze
  VERIFIED_RECOVERY_EMAIL_STATUS_IDS = [
    CustomerEmailStatus::VERIFIED,
    CustomerEmailStatus::VERIFIED_WITH_SIGN_UP,
  ].freeze
  VERIFIED_RECOVERY_TELEPHONE_STATUS_IDS = [
    CustomerTelephoneStatus::VERIFIED,
    CustomerTelephoneStatus::VERIFIED_WITH_SIGN_UP,
  ].freeze
  RECOVERY_IDENTITY_REQUIRED_MESSAGE = I18n.t("models.customer.recovery_identity_required")

  attribute :status_id, default: CustomerStatus::NOTHING

  belongs_to :customer_status,
             class_name: "CustomerStatus",
             foreign_key: :status_id,
             inverse_of: :customers
  belongs_to :visibility,
             class_name: "CustomerVisibility",
             inverse_of: :customers
  has_one :customer_preference,
          dependent: :destroy,
          inverse_of: :customer
  has_many :customer_emails,
           dependent: :destroy,
           inverse_of: :customer
  has_many :customer_telephones,
           dependent: :destroy,
           inverse_of: :customer
  has_many :customer_secrets,
           dependent: :destroy,
           inverse_of: :customer
  has_many :customer_passkeys,
           dependent: :destroy,
           inverse_of: :customer
  has_many :customer_tokens,
           dependent: :delete_all,
           inverse_of: :customer

  def staff?
    false
  end

  def user?
    false
  end

  def customer?
    true
  end

  def has_verified_recovery_identity?
    has_verified_pii?
  end

  def has_verified_pii?
    verified_email? || verified_telephone?
  end

  def verified_email?
    if customer_emails.loaded?
      customer_emails.any? { |e| VERIFIED_RECOVERY_EMAIL_STATUS_IDS.include?(e.customer_email_status_id) }
    else
      customer_emails.exists?(customer_email_status_id: VERIFIED_RECOVERY_EMAIL_STATUS_IDS)
    end
  end

  def verified_telephone?
    if customer_telephones.loaded?
      customer_telephones.any? { |t| VERIFIED_RECOVERY_TELEPHONE_STATUS_IDS.include?(t.customer_telephone_status_id) }
    else
      customer_telephones.exists?(customer_telephone_status_id: VERIFIED_RECOVERY_TELEPHONE_STATUS_IDS)
    end
  end

  def passkey_login_available?
    return false unless customer_passkeys.active.exists?

    verified_telephone?
  end
end

# typed: false
# frozen_string_literal: true

class ClientExternalIdentity < AppPrincipalRecord
  PROVIDERS = %w(apple google).freeze
  STATES = %w(active consent_revoked account_deleted).freeze

  encrypts :subject, deterministic: true

  belongs_to :client, inverse_of: :client_external_identities
  has_one :client_apple_identity_credential,
          dependent: :destroy,
          inverse_of: :client_external_identity
  has_many :client_apple_notification_events,
           dependent: :nullify,
           inverse_of: :client_external_identity

  validates :provider, inclusion: { in: PROVIDERS }, uniqueness: { scope: :client_id }
  validates :issuer, :subject, :audience, :verification_authority, presence: true
  validates :state, inclusion: { in: STATES }
  validates :subject, uniqueness: { scope: :issuer }
  validates :verified_at, presence: true

  alias_attribute :uid, :subject
  alias_attribute :user_id, :client_id

  alias_method :user, :client
  alias_method :user=, :client=

  def active?
    state == "active"
  end

  def touch_authenticated!
    update!(last_authenticated_at: Time.current)
  end
end

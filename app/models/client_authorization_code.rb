# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_authorization_codes
# Database name: app_ticket
#
#  id                    :bigint           not null, primary key
#  acr                   :string
#  auth_method           :string
#  code                  :string(64)       not null
#  code_challenge        :string           not null
#  code_challenge_method :string(8)        default("S256"), not null
#  consumed_at           :datetime
#  discarded_at          :datetime         default(Infinity), not null
#  nonce                 :string
#  purged_at             :datetime         default(Infinity), not null
#  redirect_uri          :text             not null
#  scope                 :string
#  state                 :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  client_id             :string(64)       not null
#  user_id               :bigint           not null
#
# Indexes
#
#  index_client_authorization_codes_on_code     (code) UNIQUE
#  index_client_authorization_codes_on_user_id  (user_id)
#
class ClientAuthorizationCode < AppTicketRecord
  include Retainable

  CODE_TTL = 10.seconds
  CODE_BYTES = 32

  belongs_to :user, class_name: "Client"

  validates :code, presence: true, uniqueness: true, length: { maximum: 64 }
  validates :client_id, presence: true, length: { maximum: 64 }
  validates :redirect_uri, presence: true
  validates :code_challenge, presence: true
  validates :code_challenge_method, inclusion: { in: %w(S256) }, length: { maximum: 8 }
  validates :discarded_at, presence: true

  scope :valid, -> { where(consumed_at: nil).where(arel_table[:discarded_at].gt(Time.current)) }

  def resource
    user
  end

  def resource_type
    "client"
  end

  class << self
    def generate_code
      SecureRandom.urlsafe_base64(CODE_BYTES)
    end

    def issue!(client_id:, redirect_uri:, code_challenge:, code_challenge_method:, scope: nil, state: nil,
               nonce: nil, user: nil, auth_method: nil, acr: nil)
      create!(
        code: generate_code,
        user: user,
        client_id: client_id,
        redirect_uri: redirect_uri,
        code_challenge: code_challenge,
        code_challenge_method: code_challenge_method,
        scope: scope,
        state: state,
        nonce: nonce,
        auth_method: auth_method,
        acr: acr,
        discarded_at: CODE_TTL.from_now,
      )
    end
  end

  def expired?
    discarded_at <= Time.current
  end

  def consumed?
    consumed_at.present?
  end

  def revoked?
    discarded_at <= Time.current
  end

  def usable?
    !expired? && !consumed?
  end

  def consume!
    raise RuntimeError, "Authorization code already consumed" if consumed?
    raise RuntimeError, "Authorization code expired" if expired?

    update!(consumed_at: Time.current)
  end

  def revoke!
    update!(discarded_at: Time.current)
  end

  def verify_pkce(code_verifier)
    return false if code_verifier.blank?

    expected = Base64.urlsafe_encode64(
      Digest::SHA256.digest(code_verifier),
      padding: false,
    )
    ActiveSupport::SecurityUtils.secure_compare(code_challenge, expected)
  end
end

# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_authorization_codes
# Database name: mark
#
#  id                    :bigint           not null, primary key
#  acr                   :string
#  auth_method           :string
#  code                  :string(64)       not null
#  code_challenge        :string           not null
#  code_challenge_method :string(8)        default("S256"), not null
#  consumed_at           :datetime
#  expires_at            :datetime         not null
#  nonce                 :string
#  redirect_uri          :text             not null
#  revoked_at            :datetime
#  scope                 :string
#  state                 :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  client_id             :string(64)       not null
#  user_id               :bigint           not null
#
# Indexes
#
#  index_user_authorization_codes_on_code        (code) UNIQUE
#  index_user_authorization_codes_on_expires_at  (expires_at)
#  index_user_authorization_codes_on_user_id     (user_id)
#
class UserAuthorizationCode < MarkRecord
  CODE_TTL = 10.seconds
  CODE_BYTES = 32

  belongs_to :user

  validates :code, presence: true, uniqueness: true
  validates :client_id, presence: true
  validates :redirect_uri, presence: true
  validates :code_challenge, presence: true
  validates :code_challenge_method, inclusion: { in: %w(S256) }
  validates :expires_at, presence: true

  scope :valid, -> { where(consumed_at: nil, revoked_at: nil).where("expires_at > ?", Time.current) }

  def resource
    user
  end

  def resource_type
    "user"
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
        expires_at: CODE_TTL.from_now,
      )
    end
  end

  def expired?
    expires_at <= Time.current
  end

  def consumed?
    consumed_at.present?
  end

  def revoked?
    revoked_at.present?
  end

  def usable?
    !expired? && !consumed? && !revoked?
  end

  def consume!
    raise RuntimeError, "Authorization code already consumed" if consumed?
    raise RuntimeError, "Authorization code revoked" if revoked?
    raise RuntimeError, "Authorization code expired" if expired?

    update!(consumed_at: Time.current)
  end

  def revoke!
    update!(revoked_at: Time.current) unless revoked?
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

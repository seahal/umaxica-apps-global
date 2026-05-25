# typed: false
# frozen_string_literal: true

module DeviceSessionable
  extend ActiveSupport::Concern
  include ::PublicId
  include ::RefreshTokenShared

  STATUS_ACTIVE = 1
  STATUS_REVOKED = 104

  included do
    before_validation :ensure_device_id_digest, on: :create

    validates :public_id, uniqueness: true, length: { maximum: 21 }
    validates :status_id, presence: true

    scope :active, -> { where(revoked_at: nil, status_id: STATUS_ACTIVE) }
  end

  def revoked?
    revoked_at.present? || status_id == STATUS_REVOKED
  end

  def dbsc_bound?
    dbsc_bound_at.present?
  end

  def fallback_session?
    !dbsc_bound?
  end

  def revoke!(reason: "user_logout")
    now = Time.current
    update!(
      status_id: STATUS_REVOKED,
      revoked_at: revoked_at || now,
      revoke_reason: reason,
    )
  end

  def bind_dbsc!(session_id:, public_key_thumbprint: nil)
    # rubocop:disable Rails/SkipsModelValidations
    update_columns(
      dbsc_session_id_digest: self.class.digest_device_id(session_id),
      dbsc_public_key_thumbprint: public_key_thumbprint,
      dbsc_bound_at: Time.current,
      updated_at: Time.current,
    )
    # rubocop:enable Rails/SkipsModelValidations
  end

  private

  def ensure_device_id_digest
    return unless respond_to?(:device_id)

    self.device_id_digest = self.class.digest_device_id(device_id) if device_id.present? && device_id_digest.blank?
  end
end

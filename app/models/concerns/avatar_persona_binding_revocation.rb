# typed: false
# frozen_string_literal: true

module AvatarPersonaBindingRevocation
  extend ActiveSupport::Concern

  class RevocationDenied < StandardError; end

  def active?
    revoked_at.nil?
  end

  def revoked?
    revoked_at.present?
  end

  def revoke!(at: Time.current, force: false)
    return self if revoked?

    raise RevocationDenied, "active avatar persona binding revocation requires force: true" unless force

    update!(revoked_at: at)
    self
  end
end

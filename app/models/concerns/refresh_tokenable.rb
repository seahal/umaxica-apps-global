# typed: false
# frozen_string_literal: true

# Shared refresh-token behavior for token models.
# Keeps raw tokens out of the database by storing only digests.
# Required gem: sha3

module RefreshTokenable
  extend ActiveSupport::Concern
  include RefreshTokenShared

  REFRESH_TTL = 30.days

  included do
    before_validation :ensure_lapses_at, on: :create
    before_validation :ensure_refresh_token_family_id, on: :create
    before_validation :ensure_refresh_token_generation, on: :create
    before_validation :ensure_device_id, on: :create
    before_validation :ensure_device_id_digest, on: :create
    validates :refresh_token_digest, uniqueness: true, allow_nil: true
  end

  class_methods do
    def rotate_refresh!(presented_refresh_digest:, device_id:, now: Time.current)
      return { status: :invalid, token: nil } if presented_refresh_digest.blank?

      operation = -> { find_by(refresh_token_digest: presented_refresh_digest) }
      current_token = defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call

      return { status: :invalid, token: nil } unless current_token

      if device_id.present? && current_token.device_id.present? && current_token.device_id != device_id
        return { status: :invalid, token: current_token }
      end

      operation =
        lambda do
          transaction do
            current_token.lock!
            current_token.reload

            return { status: :replay, token: current_token } if current_token.rotated_at.present?
            return { status: :invalid, token: current_token } unless current_token.currently_usable?(now)
            return { status: :invalid,
                     token: current_token, } unless current_token.refresh_token_digest == presented_refresh_digest

            current_token.update!(rotated_at: now, last_used_at: now, updated_at: now)

            replacement, raw_refresh_token = create_rotated_token_record!(current_token)

            {
              status: :rotated,
              token: replacement,
              previous_token: current_token,
              refresh_token: raw_refresh_token,
            }
          end
        end

      defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
    end

    private

    def create_rotated_token_record!(previous_token)
      actor_key = actor_foreign_key_from(previous_token)
      token_status_key = token_status_key_from(previous_token)
      token_kind_key = token_kind_key_from(previous_token)

      attrs = {
        refresh_token_family_id: previous_token.refresh_token_family_id.presence || SecureRandom.uuid,
        refresh_token_generation: Integer(previous_token.refresh_token_generation.to_s, 10) + 1,
        lapses_at: previous_token.lapses_at,
        device_id: previous_token.device_id,
        device_id_digest: column_names.include?("device_id_digest") ? digest_device_id(previous_token.device_id) : nil,
        dbsc_session_id: previous_token.dbsc_session_id,
        dbsc_public_key: previous_token.dbsc_public_key,
        dbsc_challenge: previous_token.dbsc_challenge,
        dbsc_challenge_issued_at: previous_token.dbsc_challenge_issued_at,
      }
      attrs[:purge_at] = previous_token.purge_at if previous_token.has_attribute?(:purge_at)

      operation =
        lambda do
          attrs[actor_key] = previous_token.public_send(actor_key) if actor_key
          attrs[token_status_key] = previous_token.public_send(token_status_key) if token_status_key
          attrs[token_kind_key] = previous_token.public_send(token_kind_key) if token_kind_key
        end
      defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
      attrs[:user_token_binding_method_id] =
        previous_token.user_token_binding_method_id if previous_token.has_attribute?(:user_token_binding_method_id)
      attrs[:staff_token_binding_method_id] =
        previous_token.staff_token_binding_method_id if previous_token.has_attribute?(:staff_token_binding_method_id)
      attrs[:visitor_token_binding_method_id] =
        previous_token.visitor_token_binding_method_id if previous_token.has_attribute?(
          :visitor_token_binding_method_id,
        )
      attrs[:user_token_dbsc_status_id] =
        previous_token.user_token_dbsc_status_id if previous_token.has_attribute?(:user_token_dbsc_status_id)
      attrs[:staff_token_dbsc_status_id] =
        previous_token.staff_token_dbsc_status_id if previous_token.has_attribute?(:staff_token_dbsc_status_id)
      attrs[:visitor_token_dbsc_status_id] =
        previous_token.visitor_token_dbsc_status_id if previous_token.has_attribute?(:visitor_token_dbsc_status_id)

      replacement = new(attrs)
      replacement.skip_session_limit_check = true if replacement.respond_to?(:skip_session_limit_check=)
      replacement.save!

      raw_refresh_token, verifier = generate_refresh_token(public_id: replacement.public_id)
      replacement.update!(refresh_token_digest: digest_refresh_token(verifier))
      [replacement, raw_refresh_token]
    end

    def actor_foreign_key_from(token)
      return :user_id if token.has_attribute?(:user_id)
      return :staff_id if token.has_attribute?(:staff_id)

      :visitor_id
    end

    def token_status_key_from(token)
      return :user_token_status_id if token.has_attribute?(:user_token_status_id)
      return :staff_token_status_id if token.has_attribute?(:staff_token_status_id)

      :visitor_token_status_id
    end

    def token_kind_key_from(token)
      return :user_token_kind_id if token.has_attribute?(:user_token_kind_id)
      return :staff_token_kind_id if token.has_attribute?(:staff_token_kind_id)

      :visitor_token_kind_id
    end
  end

  # Whether the refresh token has expired.
  def expired_refresh?
    return false if lapses_at.blank?
    return false if lapses_at.respond_to?(:infinite?) && lapses_at.infinite?

    lapses_at <= Time.current
  end

  # Whether the token is active.
  def active?
    !revoked? && !expired_refresh?
  end

  # Rotate (refresh) the token and return the raw token for the client.
  def rotate_refresh_token!(lapses_at: nil)
    # Use a transaction to keep token state consistent.
    transaction do
      token, verifier = generate_refresh_token(public_id: public_id)

      self.refresh_token_digest = digest_refresh_token(verifier)
      self.lapses_at =
        if lapses_at
          lapses_at
        elsif self.lapses_at.respond_to?(:infinite?) && self.lapses_at.infinite?
          default_lapses_at
        else
          self.lapses_at
        end
      self.last_used_at = Time.current
      self.refresh_token_generation = Integer(refresh_token_generation.to_s, 10) + 1
      save!

      # Return the combined token for the client.
      token
    end
  end

  def refresh_token=(verifier)
    self.refresh_token_digest = verifier.blank? ? nil : digest_refresh_token(verifier)
  end

  # Authenticate the refresh token.
  def authenticate_refresh_token(verifier)
    return false unless active?

    refresh_token_digest_matches?(verifier)
  end

  def refresh_token_digest_matches?(verifier)
    return false if verifier.blank? || refresh_token_digest.blank?

    candidate = digest_refresh_token(verifier)

    secure_compare?(refresh_token_digest, candidate)
  end

  private

  def default_lapses_at
    Time.current + REFRESH_TTL
  end

  def ensure_lapses_at
    return if lapses_at.present? && !(lapses_at.respond_to?(:infinite?) && lapses_at.infinite?)

    self.lapses_at = default_lapses_at
  end

  def ensure_refresh_token_family_id
    self.refresh_token_family_id ||= SecureRandom.uuid
  end

  def ensure_refresh_token_generation
    self.refresh_token_generation ||= 0
  end

  def ensure_device_id
    return unless has_attribute?(:device_id)

    self.device_id = SecureRandom.uuid if device_id.blank?
  end

  def ensure_device_id_digest
    return unless has_attribute?(:device_id_digest)

    self.device_id_digest = digest_device_id(device_id)
  end
end

# typed: false
# frozen_string_literal: true

module SignPasskeyOptionsFlow
  extend ActiveSupport::Concern

  def options
    return unless before_passkey_options_request!

    identifier = normalized_passkey_identifier
    return render_error(passkey_identifier_required_error_key, :unprocessable_content) if identifier.blank?

    return render_error(
      passkey_identifier_invalid_error_key,
      :unprocessable_content,
    ) unless valid_passkey_identifier?(identifier)

    actor = find_active_passkey_actor(identifier)
    return render_error("errors.webauthn.no_passkeys_available", :unprocessable_content) unless actor
    return unless allow_passkey_options_for_actor?(actor)

    passkeys = active_passkeys_for_actor(actor)
    return render_error("errors.webauthn.no_passkeys_available", :unprocessable_content) if passkeys.empty?

    challenge_id, request_options = generate_challenge_options(passkeys, actor)

    render json: {
      challenge_id: challenge_id,
      options: request_options,
    }, status: :ok
  rescue SignWebauthn::OriginValidationError => e
    Rails.logger.error(JitLogEvent.format("webauthn.origin_validation_failed", message: e.message))
    render_error("errors.webauthn.origin_invalid", :forbidden)
  rescue StandardError => e
    Rails.logger.error(
      JitLogEvent.format(
        "webauthn.authentication_options_failed", error_class: e.class.name,
                                                  message: e.message,
      ),
    )
    render_error("errors.webauthn.options_failed", :unprocessable_content)
  end

  private

  def before_passkey_options_request!
    true
  end

  def normalized_passkey_identifier
    params(:identifier).to_s.strip
  end

  def passkey_identifier_required_error_key
    "errors.webauthn.identifier_required"
  end

  def valid_passkey_identifier?(_identifier)
    true
  end

  def passkey_identifier_invalid_error_key
    passkey_identifier_required_error_key
  end

  def find_active_passkey_actor(_identifier)
    raise NotImplementedError, "#{self.class} must define #find_active_passkey_actor"
  end

  def allow_passkey_options_for_actor?(_actor)
    true
  end

  def active_passkeys_for_actor(_actor)
    raise NotImplementedError, "#{self.class} must define #active_passkeys_for_actor"
  end
end

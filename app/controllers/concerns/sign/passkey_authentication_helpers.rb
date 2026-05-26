# typed: false
# frozen_string_literal: true

module Sign
  module PasskeyAuthenticationHelpers
    extend ActiveSupport::Concern

    private

    def credential_params
      params.fetch(:credential, {}).permit(
        :id,
        :rawId,
        :type,
        :authenticatorAttachment,
        { response: %i(clientDataJSON authenticatorData signature userHandle) },
        { clientExtensionResults: {} },
      )
    end

    def retrieve_pt_for_checkpoint
      params[:pt].presence
    end

    alias_method :retrieve_pt_for_bulletin, :retrieve_pt_for_checkpoint

    def generate_challenge_options(passkeys, actor)
      allow_credentials = passkeys.map { |pk| { id: pk.webauthn_id } }
      challenge_id, request_options = create_authentication_challenge(allow_credentials: allow_credentials)

      challenges = session[Sign::Webauthn::CHALLENGE_SESSION_KEY]
      challenges[challenge_id][passkey_challenge_actor_id_key] = actor.id
      session[Sign::Webauthn::CHALLENGE_SESSION_KEY] = challenges

      [challenge_id, request_options]
    end

    def render_error(message_key, status)
      render json: { error: I18n.t(message_key) }, status: status
    end
  end
end

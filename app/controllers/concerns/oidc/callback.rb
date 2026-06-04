# typed: false
# frozen_string_literal: true

module Oidc
  module Callback
    extend ActiveSupport::Concern

    InvalidCallbackState = Class.new(StandardError)

    def show
      validate_state!
      token_result = exchange_code!
      return render_callback_failure(token_result.error) unless token_result.success?

      id_token_result = verify_id_token!(token_result.token_response[:id_token])
      return render_callback_failure(id_token_result.error) unless id_token_result.success?

      resource = provision_rp_account_from_id_token!(id_token_result.payload)
      login_result =
        ActiveRecord::Base.connected_to(role: :writing) do
          log_in(
            resource, token_kind_id: "BROWSER_WEB", require_totp_check: false,
                      audit_context: { oidc_client_id: oidc_client_id },
                      bootstrap_actor: true,
          )
        end
      return render_callback_failure("login_failed") unless login_result[:status] == :success

      redirect_to(consume_oidc_pt, allow_other_host: false)
    rescue InvalidCallbackState
      clear_oidc_session_state!
      render plain: I18n.t("errors.messages.login_required"), status: :unprocessable_content
    end

    private

    def validate_state!
      expected = session.delete(:oidc_state).to_s
      actual = params[:state].to_s
      unless expected.present? && actual.present? && expected.bytesize == actual.bytesize &&
          ActiveSupport::SecurityUtils.secure_compare(expected, actual)
        raise InvalidCallbackState, "OIDC state mismatch"
      end
    end

    def exchange_code!
      code_verifier = session.delete(:oidc_code_verifier)
      raise InvalidCallbackState, "OIDC PKCE verifier missing" if code_verifier.blank?

      Oidc::RpTokenClient.call(
        token_url: oidc_token_url,
        client_id: oidc_client_id,
        client_secret: oidc_client_secret,
        code: params[:code],
        redirect_uri: oidc_callback_url,
        code_verifier: code_verifier,
      )
    end

    def verify_id_token!(id_token)
      Oidc::IdTokenVerifier.call(
        id_token: id_token,
        client_id: oidc_client_id,
        resource_type: oidc_resource_type,
        expected_nonce: session.delete(:oidc_nonce),
        issuer: Oidc::Issuer.for_client(oidc_client),
        jwt_issuer_id: Oidc::Issuer.jwt_issuer_id_for_client(oidc_client),
      )
    end

    def oidc_client_secret
      oidc_client&.client_secret
    end

    def consume_oidc_pt
      session.delete(:oidc_pt).presence || "/"
    end

    def render_callback_failure(error)
      Rails.logger.info(
        Jit::LogEvent.format(
          "oidc.rp.callback.failed",
          error: error,
          client_id: oidc_client_id,
          host: request.host,
        ),
      )
      clear_oidc_session_state!
      redirect_to("/", alert: I18n.t("errors.messages.login_required"), allow_other_host: false)
    end

    def clear_oidc_session_state!
      session.delete(:oidc_code_verifier)
      session.delete(:oidc_state)
      session.delete(:oidc_nonce)
      session.delete(:oidc_pt)
    end

    def oidc_resource_type
      Oidc::Issuer.resource_type_for_client(oidc_client)
    end

    def oidc_client
      @oidc_client ||= Oidc::ClientRegistry.find!(oidc_client_id)
    end

    def oidc_client_id
      raise NotImplementedError, "controller must define oidc_client_id"
    end

    def provision_rp_account_from_id_token!(_payload)
      raise NotImplementedError, "controller must provision RP account"
    end
  end
end

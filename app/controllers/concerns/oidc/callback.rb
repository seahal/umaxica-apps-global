# typed: false
# frozen_string_literal: true

module Oidc
  module Callback
    extend ActiveSupport::Concern

    included do
      public_strict!
    end

    def show
      validate_state!

      result = Oidc::TokenExchangeService.call(
        grant_type: "authorization_code",
        code: params[:code],
        redirect_uri: oidc_callback_url,
        client_id: oidc_client_id,
        client_secret: oidc_client_secret,
        code_verifier: session.delete(:oidc_code_verifier),
      )

      if result.success?
        set_auth_cookies_from_token_response(result.token_response)
        return_to = session.delete(:oidc_return_to)
        redirect_to(return_to || "/", allow_other_host: false)
      else
        Rails.event.notify(
          "oidc.callback.failed",
          error: result.error,
          error_description: result.error_description,
          client_id: oidc_client_id,
          host: request.host,
        )
        redirect_to("/", alert: I18n.t("errors.messages.login_required"))
      end
    end

    private

    def validate_state!
      expected_state = session.delete(:oidc_state)
      return if expected_state.blank? && params[:state].blank?

      return if ActiveSupport::SecurityUtils.secure_compare(expected_state.to_s, params[:state].to_s)

      raise ActionController::InvalidCrossOriginRequest, "OIDC state mismatch"
    end

    def set_auth_cookies_from_token_response(token_response)
      now = Time.current
      access_expires_at = now + Authentication::Base::ACCESS_TOKEN_TTL
      refresh_expires_at = now + Authentication::Base::REFRESH_TOKEN_TTL

      set_auth_cookies(
        access_token: token_response[:access_token],
        refresh_token: token_response[:refresh_token],
        device_id: "",
        access_expires_at: access_expires_at,
        refresh_expires_at: refresh_expires_at,
      )
    end

    def oidc_callback_url
      protocol = request.protocol
      host = request.host
      port = request.port
      port_suffix = [80, 443].include?(port) ? "" : ":#{port}"
      "#{protocol}#{host}#{port_suffix}/auth/callback"
    end

    # Override in each RP controller
    def oidc_client_id
      raise NotImplementedError, "Subclass must define oidc_client_id"
    end

    def oidc_client_secret
      client = Oidc::ClientRegistry.find(oidc_client_id)
      client&.client_secret
    end
  end
end

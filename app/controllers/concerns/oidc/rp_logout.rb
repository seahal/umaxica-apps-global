# typed: false
# frozen_string_literal: true

module Oidc
  module RpLogout
    extend ActiveSupport::Concern

    included do
      declare_authentication_mode! :open
    end

    def create
      log_out
      redirect_to_jump_url(oidc_logout_url)
    end

    private

    def oidc_logout_url
      ri = params[:ri].presence || "jp"
      uri = URI::Generic.build(
        scheme: oidc_sign_scheme,
        host: oidc_sign_host,
        port: oidc_port,
        path: "/oidc/logout",
      )
      uri.query = {
        client_id: oidc_client_id,
        logout_request: Oidc::LogoutRequest.issue(client_id: oidc_client_id, ri: ri),
        ri: ri,
      }.to_query
      uri.to_s
    end

    def oidc_sign_scheme
      return "http" if !request.ssl? && oidc_sign_host.to_s.end_with?(".localhost")

      "https"
    end
  end
end

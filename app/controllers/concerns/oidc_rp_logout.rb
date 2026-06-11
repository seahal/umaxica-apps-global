# typed: false
# frozen_string_literal: true

module OidcRpLogout
  extend ActiveSupport::Concern

  def create
    log_out
    redirect_to(
      "/",
      notice: rp_local_logout_notice,
      allow_other_host: false,
      status: :see_other,
    )
  end

  private

  def rp_local_logout_notice
    I18n.t(
      "oidc.rp_logout.local_only",
      # rubocop:disable I18n/RailsI18n/DecorateString
      default: "This domain has been signed out. You are still signed in to sign. To sign out everywhere, " \
               "use session management at %{idp_sessions_url}.",
      # rubocop:enable I18n/RailsI18n/DecorateString
      idp_sessions_url: idp_session_management_url,
    )
  end

  def idp_session_management_url
    ri = params[:ri].presence || "jp"
    uri = URI::Generic.build(
      scheme: oidc_acme_scheme,
      host: oidc_acme_host,
      port: oidc_port,
      path: "/settings/sessions",
    )
    uri.query = { ri: ri }.to_query
    uri.to_s
  end

  def oidc_acme_scheme
    return "http" if !request.ssl? && oidc_acme_host.to_s.end_with?(".localhost")

    "https"
  end
end

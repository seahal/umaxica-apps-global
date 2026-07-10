# typed: false
# frozen_string_literal: true

require "base64"
require "openssl"

# Shared support for the org Entra ID sign-in ceremony controllers
# (Sign::In::EntrasController, Sign::In::Entra::AuthorizationsController,
# Sign::In::Entra::CallbacksController).
#
# Security invariants:
# - `state` stored in session provides CSRF protection for the callback.
# - `nonce` stored in session is verified inside the ID token.
# - PKCE S256 prevents authorization code interception.
# - Only pre-provisioned, ACTIVE (OperatorEntraIdentity + connection) operators can sign in.
# - No JIT provisioning: resolver raises IdentityNotFoundError on any miss.
# - OmniAuth on the org surface is NOT used; see OmniAuthNonAppSocialGuard.
#
# See adr/org-entra-id-sign-in-boundary.md.
module OrgEntraCeremony
  extend ActiveSupport::Concern

  ENTRA_AUTHORIZE_TEMPLATE = "https://login.microsoftonline.com/%s/oauth2/v2.0/authorize"
  ENTRA_TOKEN_TEMPLATE     = "https://login.microsoftonline.com/%s/oauth2/v2.0/token"
  ENTRA_SCOPE              = "openid profile"

  private

  def cleanup_entra_session!
    session.delete(:entra_nonce)
    session.delete(:entra_code_verifier)
    session.delete(:entra_pt)
    session.delete(:entra_connection_public_id)
  end

  def find_active_connection_from_params
    public_id = entra_params[:connection_public_id].to_s.strip
    return if public_id.blank?

    OrganizationEntraConnection.find_by(
      public_id: public_id,
      status_id: OrganizationEntraConnectionState::ACTIVE,
    )
  end

  def find_active_connection_from_session
    public_id = session[:entra_connection_public_id].to_s
    return if public_id.blank?

    OrganizationEntraConnection.find_by(
      public_id: public_id,
      status_id: OrganizationEntraConnectionState::ACTIVE,
    )
  end

  def entra_params
    params.fetch(:entra, {}).permit(:connection_public_id)
  end

  def build_entra_authorization_url(connection:, state:, nonce:, code_challenge:)
    base = format(ENTRA_AUTHORIZE_TEMPLATE, connection.entra_tenant_id)
    query = {
      client_id: connection.entra_client_id,
      response_type: "code",
      redirect_uri: auth_org_sign_in_entra_callback_url,
      scope: ENTRA_SCOPE,
      state: state,
      nonce: nonce,
      code_challenge: code_challenge,
      code_challenge_method: "S256",
    }.to_query
    "#{base}?#{query}"
  end

  def pkce_s256_challenge(code_verifier)
    digest = OpenSSL::Digest::SHA256.digest(code_verifier)
    Base64.urlsafe_encode64(digest, padding: false)
  end

  # Renders the shared Entra landing template so every ceremony controller
  # reports errors on the same page.
  def render_entra_error(reason)
    @error_reason = reason
    render "auth/org/sign/in/entras/new", status: :unprocessable_content, formats: :html
  end

  def log_entra_failure(event, **context)
    Rails.logger.info(
      JitLogEvent.format(
        "sign.org.authentication.entra.failed",
        event: event,
        ip: request.remote_ip,
        ri: current_region_identifier,
        **context,
      ),
    )
  end

  def secure_equal?(lhs, rhs)
    lhs = lhs.to_s
    rhs = rhs.to_s
    return false if lhs.empty? || rhs.empty?
    return false if lhs.bytesize != rhs.bytesize

    ActiveSupport::SecurityUtils.secure_compare(lhs, rhs)
  end
end

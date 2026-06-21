# typed: false
# frozen_string_literal: true

module OidcRpLogoutLauncher
  extend ActiveSupport::Concern

  private

  def launch_oidc_rp_logout!(client_id:, issuer_resource_type:, token_issuer:)
    return render_oidc_rp_logout_unavailable if current_resource.blank? || current_session_public_id.blank?

    id_token_hint = oidc_rp_logout_id_token_hint(
      client_id: client_id,
      issuer_resource_type: issuer_resource_type,
      token_issuer: token_issuer,
    )
    return render_oidc_rp_logout_unavailable if id_token_hint.blank?

    state = SecureRandom.urlsafe_base64(32)
    prepare_sign_out_completion_notice!(state: state)
    logout_current_session!(reason: "user_logout")
    issue_sign_out_notice!
    redirect_to(
      acme_oidc_logout_url(
        ri: params[:ri],
        id_token_hint: id_token_hint,
        post_logout_redirect_uri: sign_out_complete_url,
        state: state,
      ),
      status: :temporary_redirect,
      allow_other_host: true,
    )
  end

  def complete_oidc_rp_logout!
    completion_state = session[SignOutNotice::SIGN_OUT_NOTICE_SESSION_KEY]
    return render_oidc_rp_logout_completion unless completion_state.is_a?(Hash)

    expected_state = completion_state["state"].to_s
    provided_state = params[:state].to_s
    return render_oidc_rp_logout_completion if expected_state.blank? || provided_state.blank?
    return render_oidc_rp_logout_completion unless expected_state.length == provided_state.length
    return render_oidc_rp_logout_completion unless ActiveSupport::SecurityUtils.secure_compare(
      expected_state,
      provided_state,
    )

    consume_sign_out_notice
    render_oidc_rp_logout_completion
  end

  def oidc_rp_logout_id_token_hint(client_id:, issuer_resource_type:, token_issuer:)
    OidcIdTokenIssuer.call(
      resource: current_resource,
      client: OidcClientRegistry.find!(client_id),
      nonce: "sign-out",
      issuer: OidcIssuer.for_resource_type(issuer_resource_type),
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(issuer_resource_type),
      subject: OidcSubject.for(current_resource, resource_type: token_issuer),
      sid: current_session_public_id,
    )
  end

  def acme_oidc_logout_url(**query)
    public_send(
      "acme_#{sign_surface_name}_oidc_logout_url",
      host: oidc_acme_host,
      ri: params[:ri],
      **query,
    )
  end

  def oidc_acme_host
    case sign_surface_name
    when "app"
      ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    when "com"
      ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    when "org"
      ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    else
      ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    end
  end

  def render_oidc_rp_logout_unavailable
    render_oidc_rp_logout_completion
  end

  def render_oidc_rp_logout_completion
    @sign_out_notice = consume_sign_out_notice
    render "sign/shared/sign_outs/complete", status: :ok
  end

  def sign_surface_name
    controller_path.split("/").second
  end
end

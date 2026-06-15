# typed: false
# frozen_string_literal: true

module OidcRpLogoutReceiver
  extend ActiveSupport::Concern

  private

  def handle_oidc_backchannel_logout
    result = OidcLogoutTokenCodec.decode(
      logout_token: params[:logout_token].to_s,
      client_id: oidc_rp_logout_client_id,
      resource_type: oidc_rp_logout_resource_type,
    )
    return render plain: "invalid_logout_token", status: :bad_request unless result.success?

    OidcRpSessionLogout.call(
      resource_type: oidc_rp_logout_resource_type,
      sid: result.payload["sid"],
      reason: "oidc_backchannel_logout",
    )
    head :ok
  end

  def handle_oidc_frontchannel_logout
    return render plain: "invalid_issuer", status: :bad_request unless valid_frontchannel_issuer?

    OidcRpSessionLogout.call(
      resource_type: oidc_rp_logout_resource_type,
      sid: params[:sid].to_s,
      reason: "oidc_frontchannel_logout",
    )
    redirect_to("/", allow_other_host: false, status: :see_other)
  end

  def valid_frontchannel_issuer?
    expected = OidcIssuer.for_resource_type(oidc_rp_logout_resource_type)
    actual = params[:iss].to_s
    actual.present? && expected.bytesize == actual.bytesize &&
      ActiveSupport::SecurityUtils.secure_compare(expected, actual)
  end

  def oidc_rp_logout_resource_type
    case self.class.name
    when /::Org::/ then "operator"
    when /::Com::/ then "visitor"
    else "client"
    end
  end

  def oidc_rp_logout_client_id
    self.class.name.start_with?("Core::") ? "core-next-rp" : "sign-rp"
  end
end

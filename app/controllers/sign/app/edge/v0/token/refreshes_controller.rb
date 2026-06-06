# typed: false
# frozen_string_literal: true

class Sign::App::Edge::V0::Token::RefreshesController < ::Sign::App::ApplicationController
  include SignEdgeV0JsonApi

  include ::PreferenceWebCookieEndpoint

  AUTHENTICATION_MODE = :deny_all

  declare_authentication_mode! :open
  before_action :ensure_json_request
  skip_before_action :set_region, raise: false
  skip_before_action :set_preferences_cookie
  skip_before_action :transparent_refresh_access_token

  def create
    response.set_header("Cache-Control", "no-store")

    # Read refresh token from params or cookie
    refresh_plain = params[:refresh_token].presence || cookies[AuthenticationBase::REFRESH_COOKIE_KEY]

    if refresh_plain.blank?
      render json: {
        error: I18n.t("sign.token_refresh.errors.missing_refresh_token"),
        error_code: "missing_refresh_token",
      }, status: :bad_request
      return
    end

    refresh_public_id, = token_class.parse_refresh_token(refresh_plain.to_s)
    token_record = find_refresh_token_record(refresh_public_id)
    if token_record&.restricted?
      handle_restricted_refresh_rejected(token_record, refresh_public_id)
      render json: {
        error: I18n.t(token_refresh_error_key(refresh_failure_code)),
        error_code: refresh_failure_code,
      }, status: refresh_failure_status
      return
    end

    # refresh_access_token now automatically sets cookies (even for JSON)
    credentials = refresh_access_token(refresh_plain)

    if credentials
      sync_consented_buffer_cookie_safely!
      render json: { refreshed: true, dbsc: credentials[:dbsc] }, status: :ok
    else
      status = refresh_failure_status
      code = refresh_failure_code
      render json: {
        error: I18n.t(token_refresh_error_key(code)),
        error_code: code,
      }, status: status
    end
  end

  private

  def token_refresh_error_key(code)
    {
      "invalid_refresh_token" => "sign.token_refresh.errors.invalid_refresh_token",
      "withdrawal_required" => "sign.token_refresh.errors.withdrawal_required",
      "restricted_session" => "sign.token_refresh.errors.restricted_session",
    }.fetch(code) { "sign.token_refresh.errors.invalid_refresh_token" }
  end
end

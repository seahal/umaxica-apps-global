# typed: false
# frozen_string_literal: true

module AcmeOauthEndpoint
  extend ActiveSupport::Concern

  private

  def skip_oauth_session!
    request.session_options[:skip] = true
  end

  def set_oauth_cache_headers
    response.headers["Cache-Control"] = "no-store"
    response.headers["Pragma"] = "no-cache"
  end

  def render_oauth_bearer_error(error)
    case error
    when "insufficient_scope"
      response.set_header("WWW-Authenticate", 'Bearer error="insufficient_scope", scope="openid"')
      render json: { error: error }, status: :forbidden
    when "invalid_token"
      response.set_header("WWW-Authenticate", 'Bearer error="invalid_token"')
      render json: { error: error }, status: :unauthorized
    else
      response.set_header("WWW-Authenticate", "Bearer")
      render json: { error: error }, status: :unauthorized
    end
  end
end

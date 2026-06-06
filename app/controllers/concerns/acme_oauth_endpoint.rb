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
end

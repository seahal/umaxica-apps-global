# typed: false
# frozen_string_literal: true

module Acme
  module OauthEndpoint
    extend ActiveSupport::Concern

    included do
      protect_from_forgery with: :null_session

      before_action :skip_oauth_session!
      after_action :set_oauth_cache_headers
    end

    private

    def skip_oauth_session!
      request.session_options[:skip] = true
    end

    def set_oauth_cache_headers
      response.headers["Cache-Control"] = "no-store"
      response.headers["Pragma"] = "no-cache"
    end
  end
end

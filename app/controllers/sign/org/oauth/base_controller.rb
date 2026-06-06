# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Oauth
      class BaseController < ::Sign::Org::BareController
        AUTHENTICATION_MODE = :bare

        protect_from_forgery with: :null_session

        before_action :skip_oauth_session!
        after_action :set_oauth_cache_headers

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
  end
end

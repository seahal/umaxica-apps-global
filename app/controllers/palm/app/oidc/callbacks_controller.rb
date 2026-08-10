# typed: false
# frozen_string_literal: true

module Palm
  module App
    module Oidc
      class CallbacksController < Palm::App::BareController
        AUTHENTICATION_MODE = :bare

        before_action :skip_callback_session!
        after_action :set_callback_cache_headers

        def show
          render_callback_stub
        end

        private

        def skip_callback_session!
          request.session_options[:skip] = true
        end

        def render_callback_stub
          render(
            # rubocop:disable I18n/RailsI18n/DecorateString
            plain: "This URL is reserved for completing app authentication.\n" \
                   "Open the mobile app and try signing in again.",
            # rubocop:enable I18n/RailsI18n/DecorateString
            status: :ok,
          )
        end

        def set_callback_cache_headers
          response.headers["Cache-Control"] = "no-store"
        end
      end
    end
  end
end

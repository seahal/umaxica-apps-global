# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Up
      class BaseController < ApplicationController
        include ::RateLimit
        include ActionPolicy::Controller
        # Note: Authentication::Operator is NOT included here for unauthenticated sign-up
        include ::Preference::Global
        include ::Preference::Adoption
        include ::CurrentSupport
        include ::Finisher

        allow_browser versions: :modern

        before_action :set_preferences_cookie
        before_action :resolve_param_context
        before_action :set_region
        before_action :set_locale
        before_action :set_timezone
        before_action :set_color_theme
        before_action :set_current
        append_after_action :finish_request

        protect_from_forgery using: :header_or_legacy_token,
                             trusted_origins: HostOriginEnv.trusted_origins(
                               ENV.fetch("ID_STAFF_URL", "id.org.localhost"),
                             ),
                             with: :exception

        private

        def after_login_path
          sign_org_configuration_path
        rescue StandardError
          "/"
        end
      end
    end
  end
end

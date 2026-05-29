# typed: false
# frozen_string_literal: true

module Acme
  module App
    class JwksController < BareController
      include Authentication::JwksRendering

      AUTHENTICATION_MODE = :bare
      JWT_KEY_NAMESPACE = "ACME_APP"

      before_action :skip_jwks_session!
      skip_before_action :set_preferences_cookie, raise: false
      skip_before_action :resolve_param_context, raise: false
      skip_before_action :set_region, raise: false
      skip_before_action :set_locale, raise: false
      skip_before_action :set_timezone, raise: false
      skip_before_action :apply_localization_preferences, raise: false
      skip_before_action :set_color_theme, raise: false
    end
  end
end

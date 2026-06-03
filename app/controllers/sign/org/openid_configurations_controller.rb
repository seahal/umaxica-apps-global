# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class OpenidConfigurationsController < BareController
      AUTHENTICATION_MODE = :bare

      before_action :skip_metadata_session!
      skip_before_action :set_preferences_cookie, raise: false
      skip_before_action :resolve_param_context, raise: false
      skip_before_action :set_region, raise: false
      skip_before_action :set_locale, raise: false
      skip_before_action :set_timezone, raise: false
      skip_before_action :apply_localization_preferences, raise: false
      skip_before_action :set_color_theme, raise: false

      def show
        render json: ::Oidc::DiscoveryDocument.for_resource_type("operator")
      end

      private

      def skip_metadata_session!
        request.session_options[:skip] = true
      end
    end
  end
end

# typed: false
# frozen_string_literal: true

module Preference
  module WebCookieActions
    extend ActiveSupport::Concern

    included do
      public_strict!
      include ::Preference::WebCookieEndpoint

      skip_before_action :set_preferences_cookie, raise: false
      skip_before_action :resolve_param_context, raise: false
      skip_before_action :canonicalize_regional_params, raise: false
      skip_before_action :set_region, raise: false

      skip_before_action :set_color_theme, raise: false
      skip_before_action :set_current, raise: false
      skip_before_action :enforce_withdrawal_gate!, raise: false
      skip_before_action :transparent_refresh_access_token, raise: false
      skip_before_action :enforce_verification_if_required, raise: false
    end

    def show
      render json: cookie_consent_state, status: :ok
    end

    def update
      apply_consented_update_from_request!
      set_consented_buffer_cookie!
      render json: cookie_consent_state, status: :ok
    end
  end
end

# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Web
      module V0
        class CookiesController < PreferencesBaseController
          AUTHENTICATION_MODE = :open

          declare_authentication_mode! :open
          include ::Preference::WebCookieEndpoint
          include ::Preference::WebCookieActions

          skip_before_action :set_preferences_cookie, raise: false
          skip_before_action :set_current_actor, raise: false
        end
      end
    end
  end
end

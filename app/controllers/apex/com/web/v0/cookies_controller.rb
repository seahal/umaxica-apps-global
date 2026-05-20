# typed: false
# frozen_string_literal: true

module Apex
  module Com
    module Web
      module V0
        class CookiesController < OpenController
          public_strict!
          include ::Preference::WebCookieEndpoint
          include ::Preference::WebCookieActions

          skip_before_action :set_preferences_cookie, raise: false
          skip_before_action :set_current_actor, raise: false
        end
      end
    end
  end
end

# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Preference
      module Region
        class TimezonesController < ApplicationController
          public_strict!
          include ::Preference::Core

          def edit
            set_timezone_preferences_edit
          end

          def update
            set_timezone_preferences_update
            timezone = option_id_to_timezone(@preference_timezone.option_id, preference_prefix)
            session[:timezone] = timezone
            write_preference_cookie(::Preference::Base::TIMEZONE_COOKIE_KEY, timezone)
            redirect_to(
              edit_sign_org_preference_region_timezone_url,
              notice: t("apex.org.preferences.update_success"),
            )
          rescue PreferenceOperationError
            redirect_to(
              edit_sign_org_preference_region_timezone_url,
              alert: I18n.t("errors.messages.preference_operation_failed"),
            )
          end
        end
      end
    end
  end
end

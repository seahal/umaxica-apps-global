# typed: false
# frozen_string_literal: true

class Sign::Com::Preference::Accessibility::MotionsController < Sign::Com::PreferencesBaseController
  include ::Preference::SignScreenActions

  preference_screen :motion
end

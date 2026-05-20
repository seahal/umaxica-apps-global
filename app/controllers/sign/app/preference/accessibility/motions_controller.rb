# typed: false
# frozen_string_literal: true

class Sign::App::Preference::Accessibility::MotionsController < Sign::App::PreferencesBaseController
  include ::Preference::SignScreenActions

  preference_screen :motion
end

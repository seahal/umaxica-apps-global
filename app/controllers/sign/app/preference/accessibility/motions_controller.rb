# typed: false
# frozen_string_literal: true

class Sign::App::Preference::Accessibility::MotionsController < Sign::App::ApplicationController
  public_strict!
  include ::Preference::SignScreenActions

  preference_screen :motion
end

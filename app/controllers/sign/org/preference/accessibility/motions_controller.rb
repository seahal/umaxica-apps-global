# typed: false
# frozen_string_literal: true

class Sign::Org::Preference::Accessibility::MotionsController < Sign::Org::ApplicationController
  public_strict!
  include ::Preference::SignScreenActions

  preference_screen :motion
end

# typed: false
# frozen_string_literal: true

class Sign::Org::Preference::Accessibility::DensitiesController < Sign::Org::PreferencesBaseController
  include ::Preference::SignScreenActions

  preference_screen :density
end

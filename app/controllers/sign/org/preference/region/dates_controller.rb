# typed: false
# frozen_string_literal: true

class Sign::Org::Preference::Region::DatesController < Sign::Org::PreferencesBaseController
  include ::Preference::SignScreenActions

  preference_screen :date_format
end

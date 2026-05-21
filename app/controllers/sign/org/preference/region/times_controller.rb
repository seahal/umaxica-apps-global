# typed: false
# frozen_string_literal: true

class Sign::Org::Preference::Region::TimesController < Sign::Org::PreferencesBaseController
  include ::Preference::SignScreenActions

  preference_screen :time_format
end

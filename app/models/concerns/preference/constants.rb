# typed: false
# frozen_string_literal: true

# Preference constants shared across the application
# These constants define the structure and default values for user preferences
# stored in cookies, particularly for language, region, timezone, and theme settings.
module Preference
  module Constants
    # Keys used in preference cookies and URL parameters
    # lx: language (ja, en)
    # ri: region (jp, us)
    # tz: timezone (jst, utc)
    # ct: color theme (sy=system, dr=dark, li=light)
    PREFERENCE_KEYS = %w(lx ri tz ct).freeze

    # Default preference values applied when no user preference is set
    DEFAULT_PREFERENCES = {
      "lx" => "ja", # Japanese language
      "ri" => "jp", # Japan region
      "tz" => "jst", # Japan Standard Time
      "ct" => "sy", # System theme (follows OS preference)
    }.freeze

    # Cookie key used to store user preferences
    #    PREFERENCE_COOKIE_KEY = :"__Secure-Jit_Preferences"
  end
end

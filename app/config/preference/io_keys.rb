# typed: false
# frozen_string_literal: true

module Preference
  module IoKeys
    SECURE_COOKIE_PREFIX = "__Secure-"

    module Cookies
      THEME = "ct"
      LANGUAGE = "language"
      TIMEZONE = "tz"
      CONSENTED = "preference_consented"
      ACCESS_BASENAME = "preference_access"
      REFRESH_BASENAME = "preference_refresh"
      DBSC_BASENAME = "preference_dbsc"
      DEVICE_BASENAME = "preference_device_id"

      public_constant :THEME
      public_constant :LANGUAGE
      public_constant :TIMEZONE
      public_constant :CONSENTED
      public_constant :ACCESS_BASENAME
      public_constant :REFRESH_BASENAME
      public_constant :DBSC_BASENAME
      public_constant :DEVICE_BASENAME
    end

    module Headers
      DEVICE_ID = "X-Device-Id"
      DBSC_REGISTRATION = "Sec-Session-Registration"
      DBSC_CHALLENGE = "Sec-Session-Challenge"
      DBSC_SESSION_ID = "Sec-Session-Id"
      DBSC_RESPONSE = "Sec-Session-Response"

      public_constant :DEVICE_ID
      public_constant :DBSC_REGISTRATION
      public_constant :DBSC_CHALLENGE
      public_constant :DBSC_SESSION_ID
      public_constant :DBSC_RESPONSE
    end

    module Params
      CT = :ct
      LX = :lx
      RI = :ri
      TZ = :tz
      REFRESH_TOKEN = :refresh_token
      OPTION_ID = :option_id

      public_constant :CT
      public_constant :LX
      public_constant :RI
      public_constant :TZ
      public_constant :REFRESH_TOKEN
      public_constant :OPTION_ID
    end

    public_constant :SECURE_COOKIE_PREFIX
  end
end

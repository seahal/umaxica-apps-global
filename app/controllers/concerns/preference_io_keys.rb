# typed: false
# frozen_string_literal: true

module PreferenceIoKeys
  SECURE_COOKIE_PREFIX = "__Secure-"

  module Cookies
    THEME = "ct"
    LANGUAGE = "language"
    TIMEZONE = "tz"
    CURRENCY = "cu"
    DATE_FORMAT = "df"
    TIME_FORMAT = "tf"
    MOTION = "mo"
    DENSITY = "dn"
    PAGE_SIZE = "ps"
    CONSENTED = "preference_consented"
    ACCESS_BASENAME = "preference_access"
    REFRESH_BASENAME = "preference_refresh"
    DBSC_BASENAME = "preference_dbsc"

    public_constant :THEME
    public_constant :LANGUAGE
    public_constant :TIMEZONE
    public_constant :CURRENCY
    public_constant :DATE_FORMAT
    public_constant :TIME_FORMAT
    public_constant :MOTION
    public_constant :DENSITY
    public_constant :PAGE_SIZE
    public_constant :CONSENTED
    public_constant :ACCESS_BASENAME
    public_constant :REFRESH_BASENAME
    public_constant :DBSC_BASENAME
  end

  module Headers
    DBSC_REGISTRATION = "Sec-Session-Registration"
    DBSC_CHALLENGE = "Sec-Session-Challenge"
    DBSC_SESSION_ID = "Sec-Session-Id"
    DBSC_RESPONSE = "Sec-Session-Response"

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
    OPTION_ID = :option_id

    public_constant :CT
    public_constant :LX
    public_constant :RI
    public_constant :TZ
    public_constant :OPTION_ID
  end

  public_constant :SECURE_COOKIE_PREFIX
end

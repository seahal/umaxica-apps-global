# typed: false
# frozen_string_literal: true

module Auth
  module IoKeys
    HOST_COOKIE_PREFIX = "__Host-"

    module Cookies
      ACCESS_BASENAME = "auth_access"
      REFRESH_BASENAME = "auth_refresh"
      DBSC_BASENAME = "auth_dbsc"
      DEVICE_BASENAME = "auth_device_id"

      public_constant :ACCESS_BASENAME
      public_constant :REFRESH_BASENAME
      public_constant :DBSC_BASENAME
      public_constant :DEVICE_BASENAME
    end

    module Headers
      AUTHORIZATION = "Authorization"
      DEVICE_ID = "X-Device-Id"
      DBSC_REGISTRATION = "Sec-Session-Registration"
      DBSC_CHALLENGE = "Sec-Session-Challenge"
      DBSC_SESSION_ID = "Sec-Session-Id"
      DBSC_RESPONSE = "Sec-Session-Response"
      STRICT_DEVICE_CHECK = "X-STRICT-DEVICE-CHECK"

      public_constant :AUTHORIZATION
      public_constant :DEVICE_ID
      public_constant :DBSC_REGISTRATION
      public_constant :DBSC_CHALLENGE
      public_constant :DBSC_SESSION_ID
      public_constant :DBSC_RESPONSE
      public_constant :STRICT_DEVICE_CHECK
    end

    module Params
      RI = :ri
      PT = :pt
      NT = :nt
      XT = :xt

      public_constant :RI
      public_constant :PT
      public_constant :NT
      public_constant :XT
    end

    module Session
      DEFAULT_PT = :user_email_authentication_pt
      CHECKPOINT = :sign_in_checkpoint
      BULLETIN = CHECKPOINT

      public_constant :DEFAULT_PT
      public_constant :CHECKPOINT
      public_constant :BULLETIN
    end

    module Env
      AUTH_REFRESHED_FLAG = "auth_refreshed"

      public_constant :AUTH_REFRESHED_FLAG
    end

    public_constant :HOST_COOKIE_PREFIX
  end
end

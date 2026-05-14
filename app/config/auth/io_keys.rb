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
      TEST_BULLETIN = "X-TEST-BULLETIN"
      TEST_CURRENT_RESOURCE = "X-TEST-CURRENT-RESOURCE"
      TEST_CURRENT_USER = "X-TEST-CURRENT-USER"
      TEST_CURRENT_STAFF = "X-TEST-CURRENT-STAFF"
      TEST_CURRENT_VIEWER = "X-TEST-CURRENT-VIEWER"
      TEST_SESSION_PUBLIC_ID = "X-TEST-SESSION-PUBLIC-ID"

      public_constant :AUTHORIZATION
      public_constant :DEVICE_ID
      public_constant :DBSC_REGISTRATION
      public_constant :DBSC_CHALLENGE
      public_constant :DBSC_SESSION_ID
      public_constant :DBSC_RESPONSE
      public_constant :STRICT_DEVICE_CHECK
      public_constant :TEST_BULLETIN
      public_constant :TEST_CURRENT_RESOURCE
      public_constant :TEST_CURRENT_USER
      public_constant :TEST_CURRENT_STAFF
      public_constant :TEST_CURRENT_VIEWER
      public_constant :TEST_SESSION_PUBLIC_ID
    end

    module Params
      RI = :ri
      RT = :rt

      public_constant :RI
      public_constant :RT
    end

    module Session
      DEFAULT_RT = :user_email_authentication_rt
      CHECKPOINT = :sign_in_checkpoint
      BULLETIN = CHECKPOINT

      public_constant :DEFAULT_RT
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

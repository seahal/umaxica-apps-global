# typed: false
# frozen_string_literal: true

module Authentication
  module CookieStore
    extend ActiveSupport::Concern

    def set_login_auth_cookies(token_record, access_token, refresh_plain, access_expires_at)
      set_auth_cookies(
        access_token: access_token,
        refresh_token: refresh_plain,
        device_id: token_record.device_id,
        access_expires_at: access_expires_at,
        refresh_expires_at: refresh_cookie_expires_at_for(token_record),
        dbsc_token: dbsc_cookie_value_for(token_record),
        dbsc_expires_at: dbsc_cookie_expires_at_for(token_record),
      )
    end

    private

    def cookie_options
      authentication_cookie_service.auth_cookie_options
    end

    def cookie_deletion_options
      authentication_cookie_service.auth_cookie_deletion_options
    end

    def device_cookie_key
      authentication_cookie_service.device_cookie_key
    end

    def device_cookie_options(expires_at:)
      cookie_options.merge(expires: expires_at)
    end

    def set_device_id_cookie!(device_id, expires_at:)
      cookies[device_cookie_key] = device_cookie_options(expires_at: expires_at).merge(value: device_id)
    end

    def clear_device_id_cookie!
      cookies.delete(device_cookie_key, cookie_deletion_options)
    end

    def clear_auth_cookies!
      cookies.delete(Authentication::Base::ACCESS_COOKIE_KEY, cookie_deletion_options)
      cookies.delete(Authentication::Base::REFRESH_COOKIE_KEY, cookie_deletion_options)
      clear_dbsc_cookie!
      clear_device_id_cookie!
      @current_resource = nil
    end

    def read_device_id_cookie
      store = cookies
      cookie_value = store&.[](device_cookie_key)
      stored_value =
        if cookie_value.is_a?(Hash)
          cookie_value[:value] || cookie_value["value"]
        else
          cookie_value
        end
      stored_value.to_s.presence&.presence
    end

    def set_auth_cookies(access_token:, refresh_token:, device_id:, access_expires_at:, refresh_expires_at:,
                         dbsc_token: nil, dbsc_expires_at: nil)
      cookies[Authentication::Base::ACCESS_COOKIE_KEY] = cookie_options.merge(
        value: access_token,
        expires: access_expires_at,
      )
      cookies[Authentication::Base::REFRESH_COOKIE_KEY] = cookie_options.merge(
        value: refresh_token,
        expires: refresh_expires_at,
      )
      set_dbsc_cookie!(dbsc_token, expires_at: dbsc_expires_at) if dbsc_token.present? && dbsc_expires_at.present?
      set_device_id_cookie!(device_id, expires_at: refresh_expires_at)
    end

    def set_dbsc_cookie!(token, expires_at:)
      cookies[Authentication::Base::DBSC_COOKIE_KEY] = cookie_options.merge(
        value: token,
        expires: expires_at,
      )
    end

    def clear_dbsc_cookie!
      cookies.delete(Authentication::Base::DBSC_COOKIE_KEY, cookie_deletion_options)
    end

    def extract_access_token(cookie_key)
      return nil unless respond_to?(:request, true) && request

      Auth::AuthorizationHeader.access_token(request) || cookies[cookie_key]
    end

    def set_refresh_auth_cookies(token_record, access_token, refresh_plain, access_expires_at)
      set_auth_cookies(
        access_token: access_token,
        refresh_token: refresh_plain,
        device_id: token_record.device_id,
        access_expires_at: access_expires_at,
        refresh_expires_at: refresh_cookie_expires_at_for(token_record),
        dbsc_token: dbsc_cookie_value_for(token_record),
        dbsc_expires_at: dbsc_cookie_expires_at_for(token_record),
      )
    end

    def authentication_cookie_service
      @authentication_cookie_service ||= Authentication::CookieService.new(cookies, request)
    end
  end
end

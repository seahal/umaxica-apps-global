# typed: false
# frozen_string_literal: true

module Auth
  class CookieService
    attr_reader :cookies, :request

    def initialize(cookies, request)
      @cookies = cookies
      @request = request
    end

    def set_auth_cookies(access_token:, refresh_token:, device_id:, access_ttl:, refresh_ttl:)
      cookies[access_cookie_key] = cookie_options(expires: access_ttl.from_now).merge(value: access_token)
      cookies[refresh_cookie_key] = cookie_options(expires: refresh_ttl.from_now).merge(value: refresh_token)
      set_device_id_cookie(device_id, refresh_ttl.from_now)
    end

    def set_device_id_cookie(device_id, expires_at)
      cookies[device_cookie_key] =
        device_cookie_options(expires_at: expires_at).merge(value: device_id)
    end

    def clear_auth_cookies
      cookies.delete(access_cookie_key, cookie_deletion_options)
      cookies.delete(refresh_cookie_key, cookie_deletion_options)
      clear_device_id_cookie
    end

    def clear_device_id_cookie
      cookies.delete(device_cookie_key, cookie_deletion_options)
    end

    def read_device_id_cookie
      cookies[device_cookie_key].to_s.presence
    end

    def extract_access_token_from_request
      Auth::AuthorizationHeader.access_token(request) || cookies[access_cookie_key]
    end

    def access_cookie_key
      Auth::CookieName.access
    end

    def refresh_cookie_key
      Auth::CookieName.refresh
    end

    def device_cookie_key
      Auth::CookieName.device(refresh_cookie_key: refresh_cookie_key)
    end

    private

    def cookie_options(expires: nil, httponly: true)
      Core::CookieOptions.for(
        surface: Core::Surface.current(request),
        request: request,
        httponly: httponly,
        same_site: :lax,
        path: "/",
        expires: expires,
        domain: false,
      )
    end

    def cookie_deletion_options
      Core::CookieOptions.for(
        surface: Core::Surface.current(request),
        request: request,
        same_site: :lax,
        path: "/",
        domain: false,
      ).except(:expires, :httponly, :secure, :same_site)
    end

    def device_cookie_options(expires_at:) = cookie_options(expires: expires_at, httponly: true)
  end
end

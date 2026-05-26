# typed: false
# frozen_string_literal: true

module Authentication
  class CookieService
    attr_reader :cookies, :request

    def initialize(cookies, request)
      @cookies = cookies
      @request = request
    end

    def set_auth_cookies(access_token:, refresh_token:, access_ttl:, refresh_ttl:)
      cookies[access_cookie_key] = cookie_options(expires: access_ttl.from_now).merge(value: access_token)
      cookies[refresh_cookie_key] = cookie_options(expires: refresh_ttl.from_now).merge(value: refresh_token)
    end

    def clear_auth_cookies
      cookies.delete(access_cookie_key, cookie_deletion_options)
      cookies.delete(refresh_cookie_key, cookie_deletion_options)
    end

    def extract_access_token_from_request
      Auth::AuthorizationHeader.access_token(request) || cookies[access_cookie_key]
    end

    def auth_cookie_options(expires: nil, httponly: true)
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

    def auth_cookie_deletion_options
      Core::CookieOptions.for(
        surface: Core::Surface.current(request),
        request: request,
        same_site: :lax,
        path: "/",
        domain: false,
      ).except(:expires, :httponly)
    end

    def access_cookie_key
      Authentication::CookieName.access
    end

    def refresh_cookie_key
      Authentication::CookieName.refresh
    end

    private

    def cookie_options(expires: nil, httponly: true) = auth_cookie_options(expires: expires, httponly: httponly)

    def cookie_deletion_options = auth_cookie_deletion_options
  end
end

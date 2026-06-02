# typed: false
# frozen_string_literal: true

module Authentication
  module CookieName
    module_function

    # The `production:` argument gates the `__Host-` prefix. Its default now
    # tracks `Jit::SessionCookieConfig.force_secure?` (the same predicate the
    # Rails session cookie uses), so the prefix is applied in every
    # secure-context environment (production or FORCE_SECURE_COOKIES=1), not only
    # `Rails.env.production?`. force_secure? implies the cookie is sent with the
    # Secure attribute, so the `__Host-` invariant (Secure + Path=/ + no Domain)
    # always holds whenever the prefix is added.
    def access(production: Jit::SessionCookieConfig.force_secure?)
      with_host_prefix(Auth::IoKeys::Cookies::ACCESS_BASENAME, production: production)
    end

    def refresh(production: Jit::SessionCookieConfig.force_secure?)
      with_host_prefix(Auth::IoKeys::Cookies::REFRESH_BASENAME, production: production)
    end

    def dbsc(production: Jit::SessionCookieConfig.force_secure?)
      with_host_prefix(Auth::IoKeys::Cookies::DBSC_BASENAME, production: production)
    end

    def with_host_prefix(basename, production:)
      return basename unless production

      "#{Auth::IoKeys::HOST_COOKIE_PREFIX}#{basename}"
    end
    private_class_method :with_host_prefix
  end
end

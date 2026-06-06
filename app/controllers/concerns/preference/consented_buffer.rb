# typed: false
# frozen_string_literal: true

module Preference
  module ConsentedBuffer
    extend ActiveSupport::Concern

    private

    # Write-only buffer cookie for JS. Rails must not read this cookie.
    def set_preference_consented_buffer!(consented:, expires_at:)
      cookie_options = ::Core::CookieOptions.for(
        surface: ::Core::Surface.current(request),
        request: request,
        # SameSite=Strict: this is a JS-readable projection of the JWT consent state, apex-scoped
        # for cross-subdomain reads within a surface (still same-site). The only cost of Strict is a
        # brief consent-banner flash on the first cross-site inbound hit before a same-site request
        # repopulates it; the source of truth is the JWT, not this buffer.
        same_site: :strict,
        path: "/",
      )

      cookies[Preference::IoKeys::Cookies::CONSENTED] = {
        **cookie_options,
      }.merge(
        value: consented_cookie_value(consented),
        expires: expires_at,
        httponly: false,
      )
    end

    def consented_cookie_value(consented)
      ActiveModel::Type::Boolean.new.cast(consented) ? "1" : "0"
    end
  end
end

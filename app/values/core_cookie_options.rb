# typed: false
# frozen_string_literal: true

module CoreCookieOptions
  module_function

  def for(surface:, request:, same_site: nil, expires: nil, httponly: true, secure: nil, path: nil, domain: true,
          rails_env: Rails.env)
    options = {
      httponly: httponly,
      secure: secure.nil? ? resolve_secure(request) : secure,
    }
    options[:same_site] = same_site if same_site
    options[:expires] = expires if expires
    options[:path] = path if path
    options[:partitioned] = true if rails_env.production?

    if domain
      cookie_domain = CoreCookieDomain.for(surface: surface, request_host: request.host)
      options[:domain] = cookie_domain if cookie_domain.present?
    end
    options
  end

  def resolve_secure(request)
    Rails.env.production? || ENV["FORCE_SECURE_COOKIES"].present? || request.ssl?
  end
  private_class_method :resolve_secure
end

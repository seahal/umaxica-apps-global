# typed: false
# frozen_string_literal: true

module Preference
  module CookieName
    module_function

    def access(production: Rails.env.production?, surface: nil)
      with_secure_prefix(scoped_basename(Preference::IoKeys::Cookies::ACCESS_BASENAME, surface), production: production)
    end

    def refresh(production: Rails.env.production?, surface: nil)
      with_secure_prefix(
        scoped_basename(Preference::IoKeys::Cookies::REFRESH_BASENAME, surface),
        production: production,
      )
    end

    def dbsc(production: Rails.env.production?, surface: nil)
      with_secure_prefix(scoped_basename(Preference::IoKeys::Cookies::DBSC_BASENAME, surface), production: production)
    end

    def device(production: Rails.env.production?, refresh_cookie_key: nil, surface: nil)
      return refresh_cookie_key.sub(
        Preference::IoKeys::Cookies::REFRESH_BASENAME,
        Preference::IoKeys::Cookies::DEVICE_BASENAME,
      ) if refresh_cookie_key

      with_secure_prefix(scoped_basename(Preference::IoKeys::Cookies::DEVICE_BASENAME, surface), production: production)
    end

    def with_secure_prefix(basename, production:)
      return basename unless production

      "#{Preference::IoKeys::SECURE_COOKIE_PREFIX}#{basename}"
    end
    private_class_method :with_secure_prefix

    def scoped_basename(basename, surface)
      normalized_surface = surface.to_s.downcase
      return basename unless %w(app com org).include?(normalized_surface)

      "#{normalized_surface}_#{basename}"
    end
    private_class_method :scoped_basename
  end
end

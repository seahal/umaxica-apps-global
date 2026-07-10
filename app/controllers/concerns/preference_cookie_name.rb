# typed: false
# frozen_string_literal: true

module PreferenceCookieName
  LEGACY_SURFACES = %w(app com org).freeze

  module_function

  def access(production: JitSessionCookieConfig.force_secure?, surface: nil)
    _ = surface
    with_host_prefix(PreferenceIoKeys::Cookies::ACCESS_BASENAME, production: production)
  end

  def refresh(production: JitSessionCookieConfig.force_secure?, surface: nil)
    _ = surface
    with_host_prefix(PreferenceIoKeys::Cookies::REFRESH_BASENAME, production: production)
  end

  def dbsc(production: JitSessionCookieConfig.force_secure?, surface: nil)
    _ = surface
    with_host_prefix(PreferenceIoKeys::Cookies::DBSC_BASENAME, production: production)
  end

  def legacy_access_names(surface: nil, production: JitSessionCookieConfig.force_secure?)
    legacy_names(PreferenceIoKeys::Cookies::ACCESS_BASENAME, surface: surface, production: production)
  end

  def legacy_refresh_names(surface: nil, production: JitSessionCookieConfig.force_secure?)
    legacy_names(PreferenceIoKeys::Cookies::REFRESH_BASENAME, surface: surface, production: production)
  end

  def legacy_dbsc_names(surface: nil, production: JitSessionCookieConfig.force_secure?)
    legacy_names(PreferenceIoKeys::Cookies::DBSC_BASENAME, surface: surface, production: production)
  end

  def legacy_names(basename, surface:, production:)
    surfaces =
      if LEGACY_SURFACES.include?(surface.to_s.downcase)
        [surface.to_s.downcase]
      else
        LEGACY_SURFACES
      end

    names = surfaces.map { |legacy_surface| with_host_prefix("#{legacy_surface}_#{basename}", production: production) }
    names << with_host_prefix(basename, production: production)
    if production
      names.concat(surfaces.map { |legacy_surface| "__Secure-#{legacy_surface}_#{basename}" })
      names << "__Secure-#{basename}"
    end
    names.uniq
  end
  private_class_method :legacy_names

  def with_host_prefix(basename, production:)
    return basename unless production

    "#{PreferenceIoKeys::HOST_COOKIE_PREFIX}#{basename}"
  end
  private_class_method :with_host_prefix
end

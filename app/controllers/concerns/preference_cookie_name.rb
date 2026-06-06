# typed: false
# frozen_string_literal: true

module PreferenceCookieName
  module_function

  def access(production: Rails.env.production?, surface: nil)
    with_secure_prefix(scoped_basename(PreferenceIoKeys::Cookies::ACCESS_BASENAME, surface), production: production)
  end

  def refresh(production: Rails.env.production?, surface: nil)
    with_secure_prefix(
      scoped_basename(PreferenceIoKeys::Cookies::REFRESH_BASENAME, surface),
      production: production,
    )
  end

  def dbsc(production: Rails.env.production?, surface: nil)
    with_secure_prefix(scoped_basename(PreferenceIoKeys::Cookies::DBSC_BASENAME, surface), production: production)
  end

  def with_secure_prefix(basename, production:)
    return basename unless production

    "#{PreferenceIoKeys::SECURE_COOKIE_PREFIX}#{basename}"
  end
  private_class_method :with_secure_prefix

  def scoped_basename(basename, surface)
    normalized_surface = surface.to_s.downcase
    return basename unless %w(app com org).include?(normalized_surface)

    "#{normalized_surface}_#{basename}"
  end
  private_class_method :scoped_basename
end

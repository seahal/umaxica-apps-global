# typed: false
# frozen_string_literal: true

module Preference::CookieWriter
  extend ActiveSupport::Concern

  private

  def write_preference_cookie(key, value)
    cookies[key] = preference_cookie_options(
      expires_at: Preference::Base::REFRESH_TOKEN_TTL.from_now,
      httponly: false,
    ).merge(
      value: value,
    )
  end
end

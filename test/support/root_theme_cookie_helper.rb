# typed: false
# frozen_string_literal: true

module RootThemeCookieHelper
  def stub_cookie(theme)
    cookies[:root_theme] = theme
  end
end

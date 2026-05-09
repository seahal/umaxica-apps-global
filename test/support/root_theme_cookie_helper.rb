# typed: false
# frozen_string_literal: true

module RootThemeCookieHelper
  def assert_theme_cookie_for(host:, path:, label:, **params)
    host!(host)
    get(public_send(path, **params), headers: browser_headers)
    follow_redirect! if response.redirect?

    assert_response :success

    token = cookies[Preference::IoKeys::Cookies::THEME]

    assert_not_nil token, "#{label} should set the theme cookie"
    assert_includes %w(dr li sy dark light system), token.to_s
    cookies.delete(Preference::IoKeys::Cookies::THEME)
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignAppLayoutTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses

  def default_headers
    { "Host" => ENV["PRIVATE_AUTH_SERVICE_URL"] || "id.app.localhost" }
  end

  def login_headers(user)
    default_headers.merge("X-TEST-CURRENT-USER" => user.id.to_s)
  end

  test "layout links when not logged in" do
    get new_auth_app_sign_up_email_url(ri: "jp"), headers: default_headers

    assert_response :success

    # The navigation is no longer markup in the layout: the React layout renders the shared
    # `chrome` prop, so what the visitor is offered is decided here, on the server.
    navigation = inertia_props.fetch("chrome").fetch("primary_navigation")

    assert_equal(
      [
        { "label" => I18n.t("sign.app.layout.nav.sign_up"), "href" => auth_app_sign_up_path(ri: "jp") },
        { "label" => I18n.t("sign.app.layout.nav.log_in"), "href" => auth_app_sign_in_path(ri: "jp") },
      ],
      navigation,
    )

    hrefs = navigation.map { |link| link.fetch("href") }

    assert_empty hrefs.grep(%r{/configuration})
    assert_empty hrefs.grep(%r{/authentication})
  end

  # test "layout links when logged in" do
  #   user = users(:one)
  #   get new_sign_app_sign_up_telephone_url, headers: login_headers(user)

  #   assert_response :success

  #   assert_select "nav" do
  #     assert_select "a[href=?]", auth_app_sign_up_path
  #     assert_select "a[href=?]", auth_app_sign_in_path
  #     assert_select "a[href*=?]", "/configuration", count: 0
  #     assert_select "a[href*=?][data-turbo-method='delete']", "/authentication", count: 0
  #   end
  # end
end

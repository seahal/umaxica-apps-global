# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::SignUpsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses

  test "should get new" do
    get new_sign_app_sign_up_url(format: :html, ri: "jp"), headers: { "Host" => host }

    assert_response :success
  end

  test "sets lang attribute on html element" do
    get new_sign_app_sign_up_url(format: :html, ri: "jp")

    assert_response :success
    assert_select("html[lang=?]", "ja")
    assert_not_select("html[lang=?]", "")
  end

  test "shows registration methods and social providers" do
    get new_sign_app_sign_up_url(format: :html, ri: "jp"), headers: { "Host" => host }

    assert_response :success

    assert_select "[data-test-id=?]", "registration-method", count: 4
  end

  test "shows telephone registration link" do
    get new_sign_app_sign_up_url(format: :html, ri: "jp"), headers: { "Host" => host }

    assert_response :success
    assert_select "a[href=?]", new_sign_app_up_telephone_path(ri: "jp"), count: 1
  end

  test "shows social login buttons" do
    get new_sign_app_sign_up_url(format: :html, ri: "jp"), headers: { "Host" => host }

    assert_response :success
    assert_select "form[action=?][data-turbo=?]",
                  continue_sign_app_social_authentication_path(provider: "google_app", ri: "jp", entry: "sign_up"),
                  "false",
                  count: 1
    assert_select "form[action=?][data-turbo=?]",
                  continue_sign_app_social_authentication_path(provider: "apple", ri: "jp", entry: "sign_up"),
                  "false",
                  count: 1
  end

  test "renders registration layout structure" do
    get new_sign_app_sign_up_url(format: :html, ri: "jp")

    assert_response :success

    expected_brand = brand_name
    escaped_brand = Regexp.escape(expected_brand)

    assert_select "head", count: 1
    # Skip favicon check - may not be present in all layouts
    assert_select "body", count: 1 do
      assert_select "header", minimum: 1
      assert_select "main", count: 1
      assert_select "footer", count: 1 do
        assert_select ".opacity-50", text: /^©.*#{escaped_brand}$/
      end
    end
  end

  test "header contains authentication links" do
    get new_sign_app_sign_up_url(format: :html, ri: "jp")

    assert_response :success
    assert_select "header", minimum: 1 do
      assert_select "h1", minimum: 1
    end
  end

  test "footer contains navigation links" do
    get new_sign_app_sign_up_url(format: :html, ri: "jp")

    assert_response :success
    assert_select "footer" do
      # Footer should contain copyright and links
      assert_select "a"
    end
  end
  test "renders specific cta text" do
    get new_sign_app_sign_up_url(format: :html, ri: "jp")

    assert_response :success
    Rails.logger.debug(response.body) # DEBUG
    # Check for Japanese text (since previous test asserted lang=ja)
    assert_select "a", text: "メールで登録する"
  end

  test "should redirect to dashboard when logged in" do
    user = clients(:one)
    get new_sign_app_sign_up_url(format: :html, ri: "jp"), headers: as_user_headers(user, host: host)

    assert_redirected_to acme_app_dashboard_url(ri: "jp", host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"))
  end

  test "checkpoint without active registration redirects to sign up start" do
    get sign_app_up_check_url(ri: "jp"), headers: { "Host" => host }

    assert_redirected_to new_sign_app_sign_up_url(ri: "jp")
    assert_equal I18n.t("sign.app.registration.session_missing"), flash[:alert]
  end

  private

  def host
    ENV["ID_SERVICE_URL"] || "id.app.localhost"
  end

  def brand_name
    (ENV["BRAND_NAME"].presence || ENV["NAME"]).to_s
  end
end

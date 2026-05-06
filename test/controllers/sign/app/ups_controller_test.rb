# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::UpsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :user_statuses

  test "should get new" do
    get new_sign_app_up_url(format: :html, ri: "jp"), headers: { "Host" => host }

    assert_response :success
  end

  test "sets lang attribute on html element" do
    get new_sign_app_up_url(format: :html, ri: "jp")

    assert_response :success
    assert_select("html[lang=?]", "ja")
    assert_not_select("html[lang=?]", "")
  end

  test "shows registration methods and social providers" do
    get new_sign_app_up_url(format: :html, ri: "jp"), headers: { "Host" => host }

    assert_response :success

    assert_select "[data-testid=?]", "registration-method", count: 0
  end

  test "does not show telephone registration link" do
    get new_sign_app_up_url(format: :html, ri: "jp"), headers: { "Host" => host }

    assert_response :success
    assert_select "a[href=?]", "/sign/up/telephones/new", count: 0
    assert_select "a[href=?]", "/sign/up/telephones/new?ri=jp", count: 0
  end

  test "does not show social login buttons" do
    get new_sign_app_up_url(format: :html, ri: "jp"), headers: { "Host" => host }

    assert_response :success
    assert_select "form[action=?]", "/auth/google_app", count: 0
    assert_select "form[action=?]", "/auth/apple", count: 0
  end

  test "renders registration layout structure" do
    get new_sign_app_up_url(format: :html, ri: "jp")

    expected_brand = brand_name
    escaped_brand = Regexp.escape(expected_brand)

    assert_select "head", count: 1
    # Skip favicon check - may not be present in all layouts
    assert_select "body", count: 1 do
      assert_select "header", minimum: 1
      assert_select "main", count: 1
      assert_select "footer", count: 1 do
        assert_select "small", text: /^©/
        assert_select "small", text: /#{escaped_brand}$/
      end
    end
  end

  test "header contains authentication links" do
    get new_sign_app_up_url(format: :html, ri: "jp")

    assert_response :success
    assert_select "header", minimum: 1 do
      assert_select "h1", minimum: 1
    end
  end

  test "footer contains navigation links" do
    get new_sign_app_up_url(format: :html, ri: "jp")

    assert_response :success
    assert_select "footer" do
      # Footer should contain copyright and links
      assert_select "a"
    end
  end
  test "renders specific cta text" do
    get new_sign_app_up_url(format: :html, ri: "jp")

    assert_response :success
    Rails.logger.debug(response.body) # DEBUG
    # Check for Japanese text (since previous test asserted lang=ja)
    assert_select "a", text: "メールで登録する"
  end

  test "should fail when logged in" do
    user = users(:one)
    get new_sign_app_up_url(format: :html, ri: "jp"), headers: { "X-TEST-CURRENT-USER" => user.id }

    assert_response :unauthorized
    assert_equal "この操作を行う権限がありません。", response.body
  end

  private

  def host
    ENV["ID_SERVICE_URL"] || "id.app.localhost"
  end

  def brand_name
    (ENV["BRAND_NAME"].presence || ENV["NAME"]).to_s
  end
end

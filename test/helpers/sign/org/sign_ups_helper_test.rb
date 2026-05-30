# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::SignUpsHelperTest < ActionView::TestCase
  setup do
    extend Sign::Org::SignUpsHelper
  end

  test "sign_org_recruit_contact_link uses safe configured direct message URL" do
    with_env("ORG_SIGN_UP_DIRECT_MESSAGE_URL" => "https://contact.example.test/recruit?team=org") do
      html = sign_org_recruit_contact_link

      assert_includes html, I18n.t("sign.org.ups.new.recruit_link_text")
      assert_includes html, "https://contact.example.test/recruit?team=org"
      assert_includes html, "font-semibold text-slate-900 underline"
    end
  end

  test "sign_org_recruit_contact_link falls back when configured direct message URL is unsafe" do
    define_singleton_method(:params) do
      ActionController::Parameters.new(ri: "jp", lx: "en")
    end
    define_singleton_method(:acme_com_root_url) do |params|
      "https://com.example.test/?#{params.to_query}"
    end

    with_env(
      "ORG_SIGN_UP_DIRECT_MESSAGE_URL" => "javascript:alert(1)",
      "ACME_CORPORATE_URL" => "www.com.localhost",
    ) do
      html = sign_org_recruit_contact_link

      assert_includes html, "https://com.example.test/?host=www.com.localhost&amp;lx=en&amp;ri=jp"
      assert_not_includes html, "javascript:alert"
    end
  end

  test "sign_org_recruit_contact_link falls back to corporate root with preference params" do
    define_singleton_method(:default_url_options) do
      { ct: "dr", lx: "en", ri: "jp", tz: "jst", ignored: "value" }
    end
    define_singleton_method(:params) do
      ActionController::Parameters.new(default_url_options)
    end
    define_singleton_method(:acme_com_root_url) do |params|
      "https://com.example.test/?#{params.to_query}"
    end

    with_env(
      "ORG_SIGN_UP_DIRECT_MESSAGE_URL" => nil,
      "ACME_CORPORATE_URL" => "www.com.localhost",
    ) do
      html = sign_org_recruit_contact_link

      assert_includes html, I18n.t("sign.org.ups.new.recruit_link_text")
      assert_includes html, "https://com.example.test/?host=www.com.localhost&amp;lx=en&amp;ri=jp"
      assert_includes html, "font-semibold text-slate-900 underline"
      assert_not_includes html, "ignored"
      assert_not_includes html, "ct=dr"
      assert_not_includes html, "tz=jst"
    end
  end

  private

  def with_env(values)
    previous = {}
    values.each do |key, value|
      previous[key] = ENV[key]
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::UpsHelperTest < ActionView::TestCase
  setup do
    extend Sign::Org::UpsHelper
  end

  test "sign_org_recruit_contact_link keeps preference params in organization root link" do
    define_singleton_method(:default_url_options) do
      { ct: "dr", lx: "en", ri: "jp", tz: "jst", ignored: "value" }
    end
    define_singleton_method(:apex_org_root_url) do |params|
      "https://org.example.test/?#{params.to_query}"
    end

    html = sign_org_recruit_contact_link

    assert_includes html, I18n.t("sign.org.ups.new.recruit_link_text")
    assert_includes html, "https://org.example.test/?ct=dr&amp;lx=en&amp;ri=jp&amp;tz=jst"
    assert_includes html, "font-semibold text-slate-900 underline"
    assert_not_includes html, "ignored"
  end
end

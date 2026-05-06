# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::RouteAliasHelperTest < ActionView::TestCase
  test "defines sign app route aliases that delegate to sign com routes" do
    url_helpers = Rails.application.routes.url_helpers
    helper_methods = ["sign_app_sample_path", :sign_app_sample_path, "sign_com_sample_path", :sign_com_sample_path]

    helper = Object.new
    url_helpers.stub(:public_instance_methods, helper_methods) do
      helper.extend Sign::Com::RouteAliasHelper
    end

    helper.define_singleton_method(:sign_com_sample_path) do |id, **options|
      "/com/#{id}?#{options.to_query}"
    end

    assert_equal "/com/42?ri=jp", helper.sign_app_sample_path(42, ri: "jp")
  end

  test "defines apex app route aliases that delegate to apex com routes" do
    url_helpers = Rails.application.routes.url_helpers
    helper_methods = ["apex_app_sample_url", :apex_app_sample_url, "apex_com_sample_url", :apex_com_sample_url]

    helper = Object.new
    url_helpers.stub(:public_instance_methods, helper_methods) do
      helper.extend Sign::Com::RouteAliasHelper
    end

    helper.define_singleton_method(:apex_com_sample_url) do |**options|
      "https://com.example.test/?#{options.to_query}"
    end

    assert_equal "https://com.example.test/?lx=en", helper.apex_app_sample_url(lx: "en")
  end
end

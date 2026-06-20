# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module App
    class RouteAliasContext
      include SignRouteAliasHelper

      def acme_authority_host = "www.app.example.test"

      def sign_app_settings_url(**options)
        "app-settings?#{options.to_query}"
      end
    end
  end

  module Com
    class RouteAliasContext
      include SignRouteAliasHelper

      def acme_authority_host = "www.com.example.test"

      def sign_com_settings_url(**options)
        "com-settings?#{options.to_query}"
      end
    end
  end

  module Org
    class RouteAliasContext
      include SignRouteAliasHelper

      def acme_authority_host = "www.org.example.test"

      def sign_org_settings_path(**options)
        "/org-settings?#{options.to_query}"
      end
    end
  end
end

class SignRouteAliasHelperTest < ActiveSupport::TestCase
  test "aliases acme app url helpers to sign app routes with the acme host" do
    context = Sign::App::RouteAliasContext.new

    assert_respond_to context, :acme_app_settings_url
    assert_equal "app-settings?host=www.app.example.test&ri=jp", context.acme_app_settings_url(ri: "jp")
  end

  test "aliases acme com url helpers to sign com routes with the acme host" do
    context = Sign::Com::RouteAliasContext.new

    assert_respond_to context, :acme_com_settings_url
    assert_equal "com-settings?host=www.com.example.test&ri=jp", context.acme_com_settings_url(ri: "jp")
  end

  test "aliases acme org path helpers without injecting a host" do
    context = Sign::Org::RouteAliasContext.new

    assert_respond_to context, :acme_org_settings_path
    assert_equal "/org-settings?ri=jp", context.acme_org_settings_path(ri: "jp")
  end
end

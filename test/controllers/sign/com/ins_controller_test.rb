# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module Com
    class InsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
      end

      test "should get new" do
        get new_sign_com_in_url(ri: "jp"), headers: { "Host" => @host }

        assert_response :success
        assert_select "h1", text: I18n.t("sign.com.authentication.new.page_title")
      end

      test "does not show social login buttons" do
        get new_sign_com_in_url(ri: "jp"), headers: { "Host" => @host }

        assert_response :success
        assert_select "form[action='/auth/google_app']", count: 0
        assert_select "form[action='/auth/google_org']", count: 0
        assert_select "form[action='/auth/apple']", count: 0
      end
    end
  end
end

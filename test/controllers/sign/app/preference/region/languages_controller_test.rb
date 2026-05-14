# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module App
    module Preference
      module Region
        class LanguagesControllerTest < ActionDispatch::IntegrationTest
          fixtures :app_preferences

          setup do
            host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
          end

          test "edit renders only japanese and english language options" do
            get edit_sign_app_preference_region_language_url(ri: "jp")

            assert_response :success

            options = css_select("select[name='preference_language[option_id]'] option").map(&:text)

            assert_equal [I18n.t("languages.japanese"), I18n.t("languages.english")], options
          end

          test "edit redirects invalid ri to fallback region" do
            get edit_sign_app_preference_region_language_url(lx: "en", ri: "kr")

            assert_redirected_to edit_sign_app_preference_region_language_url(lx: "en", ri: "jp")
          end

          test "edit redirects blank ri to fallback region" do
            get edit_sign_app_preference_region_language_url(lx: "en", ri: "")

            assert_redirected_to edit_sign_app_preference_region_language_url(lx: "en", ri: "jp")
          end
        end
      end
    end
  end
end

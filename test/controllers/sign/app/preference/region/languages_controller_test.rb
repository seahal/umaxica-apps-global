# typed: false
# frozen_string_literal: true

# rubocop:disable I18n/RailsI18n/DecorateString

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

          test "edit uses ri and lx params for japanese and english labels" do
            {
              "en" => ["Language Settings", "Change the display language for the application.", "Language"],
              "ja" => ["言語設定", "アプリケーションの表示言語を変更します。", "言語"],
            }.each do |lx, (heading, description, label)|
              %w(jp us).each do |ri|
                get edit_sign_app_preference_region_language_url(ri: ri, lx: lx)

                assert_response :success
                assert_select "h1", heading
                assert_includes css_select("section p").map { |node| node.text.strip }, description
                assert_select "label", label
              end
            end
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

# rubocop:enable I18n/RailsI18n/DecorateString

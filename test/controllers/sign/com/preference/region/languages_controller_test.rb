# typed: false
# frozen_string_literal: true

# rubocop:disable I18n/RailsI18n/DecorateString

require "test_helper"

module Sign
  module Com
    module Preference
      module Region
        class LanguagesControllerTest < ActionDispatch::IntegrationTest
          fixtures :com_preferences

          setup do
            host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
          end

          test "edit uses ri and lx params for japanese and english labels" do
            {
              "en" => ["Language Settings", "Change the display language for the corporate site.", "Language"],
              "ja" => ["言語設定", "コーポレート画面の表示言語を変更します。", "言語"],
            }.each do |lx, (heading, description, label)|
              %w(jp us).each do |ri|
                get edit_sign_com_preference_region_language_url(ri: ri, lx: lx)

                assert_response :success
                assert_select "h1", heading
                assert_includes css_select("section p").map { |node| node.text.strip }, description
                assert_select "label", label
              end
            end
          end
        end
      end
    end
  end
end

# rubocop:enable I18n/RailsI18n/DecorateString

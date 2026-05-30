# typed: false
# frozen_string_literal: true

# rubocop:disable I18n/RailsI18n/DecorateString

require "test_helper"
require "support/preference_jwt_helper"

module Sign
  module Com
    module Preference
      module Region
        # End-to-end coverage for localization driven by the Preference JWT payload
        # (the signed projection of the DB SSoT), without a ?lx override.
        #
        # Confirmed rules:
        #   - An explicitly set language wins over the ?ri region param.
        #   - An unset (default-seeded) language is dynamically seeded by ?ri
        #     (?ri=jp -> ja, ?ri=us -> en).
        class LanguagePayloadHydrationTest < ActionDispatch::IntegrationTest
          include PreferenceJwtHelper

          fixtures :com_preferences

          ENGLISH_HEADING = "Language Settings"
          JAPANESE_HEADING = "言語設定"

          setup do
            @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
            host! @host
          end

          # Renders the language edit page with a Preference JWT cookie whose payload
          # carries the given language and explicit-fields list, plus the ?ri param.
          def get_edit_with_payload(lx:, ri:, explicit:)
            preference = com_preferences(:one)
            token = encode_preference_jwt(
              preferences: { "lx" => lx, "ri" => ri, "explicit" => explicit },
              host: @host,
              public_id: preference.public_id,
              preference_type: "ComPreference",
            )

            with_preference_jwt_keys(host: @host) do
              cookies[::Preference::CookieName.access] = token
              get(edit_sign_com_preference_region_language_url(ri: ri))
            end
          end

          test "explicitly set english wins over ?ri=jp" do
            get_edit_with_payload(lx: "en", ri: "jp", explicit: ["language"])

            assert_response :success
            assert_select "h1", ENGLISH_HEADING
          end

          test "unset language is seeded to english by ?ri=us" do
            get_edit_with_payload(lx: "ja", ri: "us", explicit: [])

            assert_response :success
            assert_select "h1", ENGLISH_HEADING
          end

          test "unset language is seeded to japanese by ?ri=jp" do
            get_edit_with_payload(lx: "ja", ri: "jp", explicit: [])

            assert_response :success
            assert_select "h1", JAPANESE_HEADING
          end

          test "explicitly set japanese wins over ?ri=us" do
            get_edit_with_payload(lx: "ja", ri: "us", explicit: ["language"])

            assert_response :success
            assert_select "h1", JAPANESE_HEADING
          end
        end
      end
    end
  end
end

# rubocop:enable I18n/RailsI18n/DecorateString

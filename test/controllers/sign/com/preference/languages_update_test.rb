# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/preference_jwt_helper"

module Sign
  module Com
    module Preference
      module Region
        class LanguagesUpdateTest < ActionDispatch::IntegrationTest
          include PreferenceJwtHelper

          fixtures :com_preferences

          setup do
            @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
            @visitor = create_verified_visitor_with_email(
              email_address: "preference-#{SecureRandom.hex(4)}@example.com",
            )
            @visitor.visitor_telephones.create!(
              number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
              visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
            )
            host! @host
          end

          # Selecting English on a page reached with only ?ri=jp must remove
          # the stale request overlay and render from the freshly persisted
          # DB/JWT preference after redirect.
          test "PATCH update removes language overlay from the redirect" do
            preference = com_preferences(:one)
            ComPreferenceLanguage.create!(
              preference: preference,
              option_id: ComPreferenceLanguageOption::JA,
            )
            @visitor.create_visitor_preference!(
              region: "jp",
              language: "ja",
              timezone: "Asia/Tokyo",
              theme: "sy",
            )
            token = encode_preference_jwt(
              preferences: { "ri" => "jp", "lx" => "ja" },
              host: @host,
              public_id: preference.public_id,
              preference_type: "ComPreference",
            )

            with_preference_jwt_keys(host: @host) do
              cookies[::Preference::CookieName.access] = token

              patch sign_com_preference_language_path(ri: "jp"),
                    params: { preference_language: { option_id: ComPreferenceLanguageOption::EN } },
                    headers: as_visitor_headers(@visitor, host: @host)
            end

            assert_redirected_to edit_sign_com_preference_language_url(ri: "jp", lx: nil)

            preference.reload

            assert_equal ComPreferenceLanguageOption::EN, preference.com_preference_language.option_id
          end
        end
      end
    end
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentityAuthorityInversionGuardTest < ActiveSupport::TestCase
  fixtures_none!

  SIGN_TOKEN_ENDPOINTS = %w(
    app/controllers/sign/app/tokens_controller.rb
    app/controllers/sign/com/tokens_controller.rb
    app/controllers/sign/org/tokens_controller.rb
  ).freeze

  SIGN_USERINFO_ENDPOINTS = %w(
    app/controllers/sign/app/oauth/user_info_controller.rb
    app/controllers/sign/com/oauth/user_info_controller.rb
    app/controllers/sign/org/oauth/user_info_controller.rb
  ).freeze

  SIGN_REVOCATION_ENDPOINTS = %w(
    app/controllers/sign/app/oauth/revocations_controller.rb
    app/controllers/sign/com/oauth/revocations_controller.rb
    app/controllers/sign/org/oauth/revocations_controller.rb
  ).freeze

  test "sign oauth compatibility endpoints declare acme token authority" do
    # rubocop:disable I18n/RailsI18n/DecorateString
    assert_files_include(SIGN_TOKEN_ENDPOINTS, "Compatibility endpoint only. acme/www owns token issuance.")
    assert_files_include(SIGN_USERINFO_ENDPOINTS, "Compatibility endpoint only. acme/www owns userinfo authority.")
    assert_files_include(SIGN_REVOCATION_ENDPOINTS, "Compatibility endpoint only. acme/www owns token revocation.")
    # rubocop:enable I18n/RailsI18n/DecorateString
  end

  test "refresh rotation target path uses acme authority" do
    auth_base = file_content("app/controllers/concerns/authentication/base.rb")

    assert_includes auth_base, "Acme::RefreshTokenService.call(refresh_token: refresh_plain)"

    sign_service = file_content("app/services/sign/refresh_token_service.rb")

    # rubocop:disable I18n/RailsI18n/DecorateString
    assert_includes sign_service, "Compatibility namespace. Target-path refresh authority is acme/www."
    # rubocop:enable I18n/RailsI18n/DecorateString

    acme_service = file_content("app/services/acme/refresh_token_service.rb")

    assert_includes acme_service, "acme/www owns refresh token rotation"
    assert_includes acme_service, "< ::Sign::RefreshTokenService"
  end

  test "unknown social signup compatibility is explicit" do
    concern = file_content("app/controllers/concerns/social_auth_concern.rb")

    assert_includes concern, "established-account social login; unknown signup remains legacy for now."
    assert_includes concern, "process_social_ceremony_login_callback"
    assert_includes concern, "acme_social_login_completion_supported?"
  end

  test "sign social completion form transports only signed result to acme" do
    form = file_content("app/views/sign/shared/social_completion.html.erb")

    assert_includes form, "form_with url: completion_url, method: :post"
    assert_includes form, "hidden_field_tag :social_ceremony_result, result_token"
    assert_no_match(/\baccess_token\b/, form)
    assert_no_match(/\brefresh_token\b/, form)
    assert_no_match(/\breturn_to\b/, form)
  end

  private

  def assert_files_include(paths, expected)
    paths.each do |path|
      assert_includes file_content(path), expected, path
    end
  end

  def file_content(path)
    Rails.root.join(path).read
  end
end

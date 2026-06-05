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
  end

  test "refresh rotation implementation is physically owned by acme not sign" do
    # Behavior, not file-string: the rotation body lives on Acme; Sign is only a
    # compatibility subclass that inherits it and adds nothing of its own.
    assert_operator Sign::RefreshTokenService, :<, Acme::RefreshTokenService,
                    "Sign::RefreshTokenService must be a compatibility subclass of the acme service"

    # The sign wrapper must not redefine the rotation entry point; it inherits
    # `call` straight from acme, so the owning method lives on the acme service.
    assert_equal Acme::RefreshTokenService.method(:call).owner, Sign::RefreshTokenService.method(:call).owner,
                 "Sign wrapper must inherit `call` from acme, not define its own refresh authority"
    assert_equal Acme::RefreshTokenService.singleton_class, Acme::RefreshTokenService.method(:call).owner

    # The shared Result contract is owned by acme and reused by the sign alias.
    assert_same Acme::RefreshTokenService::Result, Sign::RefreshTokenService::Result
  end

  test "unknown social signup compatibility is explicit" do
    concern = file_content("app/controllers/concerns/social_auth_concern.rb")

    assert_includes concern, "reject_grantless_established_social_login!"
    assert_includes concern, "SocialAuthService.handle_callback"
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

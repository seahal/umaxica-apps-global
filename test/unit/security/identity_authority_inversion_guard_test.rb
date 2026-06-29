# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class IdentityAuthorityInversionGuardTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "sign routes do not expose oidc provider endpoints" do
    source = file_content("config/routes/sign.rb")

    assert_not_includes source, "resource :openid_configuration"
    assert_not_includes source, "namespace :oauth"
    assert_not_includes source, "namespace :oidc"
    assert_not_includes source, "resource :refresh"
  end

  test "refresh rotation target path uses acme authority" do
    auth_base = file_content("app/controllers/concerns/authentication_base.rb")

    assert_includes auth_base, "AcmeRefreshTokenIssuer.call(refresh_token: refresh_plain)"

    sign_service = file_content("app/services/sign_refresh_token_issuer.rb")

    # rubocop:disable I18n/RailsI18n/DecorateString
    assert_includes sign_service, "Compatibility namespace. Target-path refresh authority is acme/www."
    # rubocop:enable I18n/RailsI18n/DecorateString
  end

  test "refresh rotation implementation is physically owned by acme not sign" do
    # Behavior, not file-string: the rotation body lives on Acme; Sign is only a
    # compatibility subclass that inherits it and adds nothing of its own.
    assert_operator SignRefreshTokenIssuer, :<, AcmeRefreshTokenIssuer,
                    "SignRefreshTokenIssuer must be a compatibility subclass of the acme service"

    # The sign wrapper must not redefine the rotation entry point; it inherits
    # `call` straight from acme, so the owning method lives on the acme service.
    assert_equal AcmeRefreshTokenIssuer.method(:call).owner, SignRefreshTokenIssuer.method(:call).owner,
                 "Sign wrapper must inherit `call` from acme, not define its own refresh authority"
    assert_equal AcmeRefreshTokenIssuer.singleton_class, AcmeRefreshTokenIssuer.method(:call).owner

    # The shared Result contract is owned by acme and reused by the sign alias.
    assert_same AcmeRefreshTokenIssuer::Result, SignRefreshTokenIssuer::Result
  end

  test "unknown social signup compatibility is explicit" do
    concern = file_content("app/controllers/concerns/social_auth.rb")

    assert_includes concern, "reject_grantless_established_social_login!"
    assert_includes concern, "SocialAuthCoordinator.handle_callback"
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

  test "sign email signup checkpoint uses the shared finalize boundary" do
    controller = file_content("app/controllers/sign/app/sign/up/check/email/birthdates_controller.rb")

    assert_includes controller, "sign_up_family = \"email\""
    assert_no_match(/email_signup_completion/, controller)
    assert_no_match(/completion_acme_app_sign_up_email_url/, controller)
  end

  test "social confirmation step includes turnstile before durable signup completion" do
    form = file_content("app/views/sign/app/sign/up/check/social/confirmations/show.html.erb")

    assert_includes form, 'render "shared/cloudflare_turnstile_visible"'
    assert_includes form, "confirm_new_social_identity"
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

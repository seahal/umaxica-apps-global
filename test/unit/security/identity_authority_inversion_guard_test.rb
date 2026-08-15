# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class IdentityAuthorityInversionGuardTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "sign routes do not expose oidc provider endpoints" do
    source = file_content("config/routes/auth.rb")

    assert_not_includes source, "resource :openid_configuration"
    assert_not_includes source, "namespace :oauth"
    assert_not_includes source, "namespace :oidc"
    assert_not_includes source, "resource :refresh"
    assert_not_includes source, "resource :up, only: :show"
    assert_not_includes source, "resource :in, only: :show"
    assert_not_includes source, "resource :out, only: %i(new edit create destroy)"
  end

  test "route sources use noun lifecycle resources for edge and preference routes" do
    auth_routes = file_content("config/routes/auth.rb")
    base_routes = file_content("config/routes/base.rb")
    core_routes = file_content("config/routes/core.rb")

    assert_includes auth_routes, 'resource :status, only: :show, path: "check", controller: :checks'
    assert_includes base_routes, 'resource :status, only: :show, path: "check", controller: :checks'
    assert_includes core_routes, 'resource :renewal, only: :create, path: "refresh", controller: :refreshes'
    assert_includes base_routes, "resource :customization, only: %i(edit destroy)"
    assert_not_includes base_routes, 'path: "reset", as: :reset, controller: :resets'
    assert_includes base_routes,
                    'resource :revocation, only: :destroy, path: "sessions", controller: "revocations/alls", as: :session_set'
    assert_includes base_routes,
                    'resource :revocation, only: :destroy, path: "other_sessions", controller: "revocations/others",' \
                    "\n                              as: :other_sessions"
    assert_includes auth_routes, 'resource :registration, only: :show, path: "up", controller: :ups, as: :up'
    assert_includes auth_routes, 'resource :session, only: :show, path: "in", controller: :ins, as: :in'
    assert_includes auth_routes,
                    'resource :termination, only: %i(new edit create destroy), path: "out", controller: :outs, as: :out'
    assert_includes base_routes,
                    'resource :termination, path: "out", controller: :sign_outs, as: :sign_out, only: %i(new edit create)'
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
    assert_includes concern, "ExternalAuthenticationLoginUseCase.call"
    assert_includes concern, "ExternalAuthenticationLinkUseCase.call"
    assert_includes concern, "process_social_ceremony_login_callback"
    assert_includes concern, "acme_social_login_completion_supported?"
  end

  test "sign social completion form transports only signed result to acme" do
    form = file_content("app/views/auth/shared/social_completion.html.erb")

    assert_includes form, "form_with url: completion_url, method: :post"
    assert_includes form, "hidden_field_tag :social_ceremony_result, result_token"
    assert_no_match(/\baccess_token\b/, form)
    assert_no_match(/\brefresh_token\b/, form)
    assert_no_match(/\breturn_to\b/, form)
  end

  test "sign email signup checkpoint uses the shared finalize boundary" do
    controller = file_content("app/controllers/auth/app/sign/up/check/email/birthdates_controller.rb")

    assert_includes controller, "sign_up_family = \"email\""
    assert_no_match(/email_signup_completion/, controller)
    assert_no_match(/completion_acme_app_sign_up_email_url/, controller)
  end

  test "social confirmation step includes turnstile before durable signup completion" do
    # The confirmation step is an Inertia page now: the component draws the widget and the
    # confirmation field, and the controller is what binds the visible challenge to this ceremony.
    form = file_content("src/features/auth/signup/SocialSignUpConfirmation.tsx")

    assert_includes form, "<TurnstileWidget {...turnstile} />"
    assert_includes form, "confirm_new_social_identity"

    %w(google apple).each do |provider|
      controller = file_content(
        "app/controllers/auth/app/sign/up/check/#{provider}/confirmations_controller.rb",
      )

      assert_includes controller, "turnstile: turnstile_visible_props("
      assert_includes controller, "confirm_new_social_identity"
    end
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

# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::SignInBoundaryTest < ActiveSupport::TestCase
  test "sign-in controllers do not directly issue login tokens or cookies" do
    prohibited = [
      /ClientToken\.create/,
      /ClientDeviceSession\.create/,
      /create!.*ClientToken/,
      /create!.*ClientDeviceSession/,
      /cookies\[[^\]]*auth/,
      /auth_access/,
      /auth_refresh/,
      /bootstrap_actor:\s*true/,
    ]

    paths = [
      "app/controllers/sign/app/sign/in/emails_controller.rb",
      "app/controllers/sign/app/sign/in/passkeys_controller.rb",
      "app/controllers/sign/app/sign/in/passkey/options_controller.rb",
      "app/controllers/sign/app/sign/in/passkey/verifications_controller.rb",
      "app/controllers/sign/app/sign/in/secret_credentials_controller.rb",
      "app/controllers/sign/app/sign/in/challenges_controller.rb",
      "app/controllers/sign/app/sign/in/challenge/totps_controller.rb",
      "app/controllers/sign/app/sign/in/challenge/passkeys_controller.rb",
      "app/controllers/sign/app/sign/in/guards_controller.rb",
      "app/controllers/sign/app/sign/in/session/cancellations_controller.rb",
      "app/controllers/sign/app/sign/in/sessions_controller.rb",
      "app/controllers/sign/app/social/authentications_controller.rb",
      "app/controllers/sign/app/omniauth/omniauth_callbacks_controller.rb",
    ]

    matches =
      paths.flat_map do |path|
        text = File.read(path)
        prohibited.filter_map { |pattern| "#{path}:#{pattern.source}" if text.match?(pattern) }
      end

    assert_empty matches
  end

  test "step-up controllers do not call the shared sign-in completion gate" do
    prohibited = [
      /establish_signed_in_session!/,
      /ClientToken\.create/,
      /ClientDeviceSession\.create/,
      /create!.*ClientToken/,
      /create!.*ClientDeviceSession/,
      /bootstrap_actor:\s*true/,
    ]

    paths = [
      "app/controllers/sign/app/verification/base_controller.rb",
      "app/controllers/sign/app/verification/cancellations_controller.rb",
      "app/controllers/sign/app/verification/emails_controller.rb",
      "app/controllers/sign/app/verification/passkeys_controller.rb",
      "app/controllers/sign/app/verification/redeliveries_controller.rb",
      "app/controllers/sign/app/verification/setups_controller.rb",
      "app/controllers/sign/app/verification/totps_controller.rb",
    ]

    matches =
      paths.flat_map do |path|
        text = File.read(path)
        prohibited.filter_map { |pattern| "#{path}:#{pattern.source}" if text.match?(pattern) }
      end

    assert_empty matches
  end
end

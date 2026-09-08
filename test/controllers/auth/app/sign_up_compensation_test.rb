# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::App::SignUpCompensationTest < ActiveSupport::TestCase
  test "sign-up controllers do not directly issue tokens or cookies" do
    prohibited = [
      /ClientToken\.create/,
      /ClientDeviceSession\.create/,
      %r{cookies\[[^\]]*auth},
      /auth_access/,
      /auth_refresh/,
    ]
    paths = [
      "app/controllers/auth/app/sign/up/emails_controller.rb",
      "app/controllers/auth/app/sign/up/telephones_controller.rb",
      "app/controllers/auth/app/sign/up/check/email/otps_controller.rb",
      "app/controllers/auth/app/sign/up/check/telephone/otps_controller.rb",
      "app/controllers/auth/app/omniauth/omniauth_callbacks_controller.rb",
      "app/controllers/auth/app/social/sessions_controller.rb",
      "app/controllers/auth/app/social/registrations_controller.rb",
    ]

    matches =
      paths.flat_map do |path|
        text = File.read(path)
        prohibited.filter_map { |pattern| "#{path}:#{pattern.source}" if text.match?(pattern) }
      end

    assert_empty matches
  end
end

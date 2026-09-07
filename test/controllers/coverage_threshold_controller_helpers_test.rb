# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageThresholdControllerHelpersTest < ActiveSupport::TestCase
  test "base application controllers expose their authority hosts" do
    controllers = [Base::App::ApplicationController.new, Base::Com::ApplicationController.new, Base::Org::ApplicationController.new]
    controllers.each do |controller|
      assert_predicate controller.oidc_client_id, :present?
      assert_predicate controller.oidc_sign_host, :present?
      assert_predicate controller.oidc_base_authority_host, :present?
      assert_predicate controller.oidc_acme_host, :present?
      assert_predicate controller.oidc_base_host, :present?
    end
  end

  test "settings passkey option controllers expose registration collaborators" do
    controllers = [
      Auth::App::Settings::Passkeys::OptionsController.new,
      Auth::Com::Settings::Passkeys::OptionsController.new,
      Auth::Org::Settings::Passkeys::OptionsController.new,
    ]
    controllers.each do |controller|
      client = clients(:one)
      controller.define_singleton_method(:current_client) { client }
      controller.define_singleton_method(:current_visitor) { client }
      controller.define_singleton_method(:current_operator) { client }

      assert_same client, controller.send(:passkey_registration_actor)
      if controller.method(:recovery_passcode_top_up_credential_class).owner != PasskeyRegistrationFlow
        assert_includes [ClientSecretCredential, VisitorSecretCredential, OperatorSecretCredential],
                        controller.send(:recovery_passcode_top_up_credential_class)
      end
      if controller.method(:recovery_passcode_top_up_actor).owner != PasskeyRegistrationFlow
        assert_same client, controller.send(:recovery_passcode_top_up_actor)
      end
    end
  end

  test "settings passkey verification controllers expose registration collaborators" do
    controllers = [
      Auth::App::Settings::Passkeys::VerificationsController.new,
      Auth::Com::Settings::Passkeys::VerificationsController.new,
      Auth::Org::Settings::Passkeys::VerificationsController.new,
    ]
    controllers.each do |controller|
      client = clients(:one)
      controller.define_singleton_method(:current_client) { client }
      controller.define_singleton_method(:current_visitor) { client }
      controller.define_singleton_method(:current_operator) { client }
      if controller.respond_to?(:passkey_registration_actor, true)
        assert_same client, controller.send(:passkey_registration_actor)
      end
      if controller.method(:recovery_passcode_top_up_actor).owner != PasskeyRegistrationFlow
        assert_same client, controller.send(:recovery_passcode_top_up_actor)
      end
    end
  end
end

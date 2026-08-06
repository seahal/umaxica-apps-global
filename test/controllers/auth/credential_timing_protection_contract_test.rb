# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthCredentialTimingProtectionContractTest < ActiveSupport::TestCase
  MINIMUM_RESPONSE_BUDGET_CONTROLLERS = [
    Auth::App::Sign::In::PasskeysController,
    Auth::App::Sign::In::Passkey::OptionsController,
    Auth::App::Sign::In::Passkey::VerificationsController,
    Auth::App::Sign::In::SecretsController,
    Auth::Com::Sign::In::PasskeysController,
    Auth::Com::Sign::In::Passkey::OptionsController,
    Auth::Com::Sign::In::Passkey::VerificationsController,
    Auth::Com::Sign::In::SecretsController,
    Auth::Org::Sign::In::PasskeysController,
    Auth::Org::Sign::In::Passkey::OptionsController,
    Auth::Org::Sign::In::Passkey::VerificationsController,
    Auth::Org::Sign::In::SecretsController,
  ].freeze

  DUMMY_WORK_CONTROLLERS = [
    Auth::App::Sign::In::EmailsController,
  ].freeze

  test "credential controllers that include MinimumResponseBudget register start and enforce callbacks" do
    MINIMUM_RESPONSE_BUDGET_CONTROLLERS.each do |controller_class|
      filters = controller_class._process_action_callbacks.map(&:filter)

      assert_includes filters, :start_minimum_response_budget, controller_class.name
      assert_includes filters, :enforce_minimum_response_budget, controller_class.name
    end
  end

  test "credential controllers either use response budget or documented dummy work" do
    protected_controllers = MINIMUM_RESPONSE_BUDGET_CONTROLLERS + DUMMY_WORK_CONTROLLERS
    expected = [
      Auth::App::Sign::In::EmailsController,
      Auth::App::Sign::In::PasskeysController,
      Auth::App::Sign::In::Passkey::OptionsController,
      Auth::App::Sign::In::Passkey::VerificationsController,
      Auth::App::Sign::In::SecretsController,
      Auth::Com::Sign::In::PasskeysController,
      Auth::Com::Sign::In::Passkey::OptionsController,
      Auth::Com::Sign::In::Passkey::VerificationsController,
      Auth::Com::Sign::In::SecretsController,
      Auth::Org::Sign::In::PasskeysController,
      Auth::Org::Sign::In::Passkey::OptionsController,
      Auth::Org::Sign::In::Passkey::VerificationsController,
      Auth::Org::Sign::In::SecretsController,
    ]

    assert_equal expected.map(&:name).sort, protected_controllers.map(&:name).sort
  end

  test "email sign-in keeps explicit dummy work timing protection" do
    controller = Auth::App::Sign::In::EmailsController.new

    assert_includes controller.private_methods, :perform_dummy_otp_generation
    assert_includes controller.private_methods, :ensure_min_elapsed
  end

  # Entra ID's connection-lookup timing protection moved out of a Rails
  # controller and into the OmniAuth strategy itself
  # (lib/omniauth/strategies/umaxica_entra.rb#request_phase) when the legacy
  # Auth::Org::Sign::In::Entra::AuthorizationsController was retired (see
  # adr/org-entra-omniauth-strategy-migration.md). A Rack/OmniAuth::Strategy
  # is not an ActionController and cannot include MinimumResponseBudget, so
  # this checks the inlined equivalent instead of a registered callback.
  test "Entra OmniAuth strategy's request phase applies the same minimum response budget" do
    strategy_class = OmniAuth::Strategies::UmaxicaEntra

    assert_in_delta(150.0, strategy_class::MINIMUM_RESPONSE_BUDGET_MS)
    assert_in_delta(250.0, strategy_class::MAXIMUM_RESPONSE_BUDGET_SLEEP_MS)
    assert_includes strategy_class.private_instance_methods, :pad_to_minimum_response_budget!

    source = strategy_class.instance_method(:request_phase).source_location
    body = File.read(source.first)

    assert_match(/pad_to_minimum_response_budget!/, body)
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"

# One-time recovery-passcode reveal on the app identity surface. The page is
# rendered whether the token still holds passcodes or has already been spent.
class Base::App::Identity::RecoverySecretsControllerTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness < Base::App::Identity::RecoverySecretsController
    attr_accessor :client, :params_hash, :rendered, :template

    def current_client = client

    def params
      ActionController::Parameters.new(params_hash || {})
    end

    def base_app_identity_url(**)
      "/app/identity"
    end

    def render(template = nil, **)
      self.template = template
      self.rendered = true
    end

    def invoke(name, ...) = send(name, ...)
  end

  setup do
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    @client = Client.create!(status_id: ClientStatus::NOTHING)
    @harness = Harness.new
    @harness.client = @client
    @harness.params_hash = { token: "reveal-token", ri: "jp" }
  end

  test "show assigns recovered passcodes when the reveal token is still valid" do
    payload = IdentityOneTimeReveal::Payload.new(value: %w(one two), metadata: {})

    IdentityOneTimeReveal.stub(:consume!, payload) do
      @harness.invoke(:show)
    end

    assert_equal %w(one two), @harness.instance_variable_get(:@recovery_passcodes)
    assert_not @harness.instance_variable_get(:@missing_recovery_passcodes)
    assert_equal "shared/recovery_passcodes/show", @harness.template
  end

  test "show marks the passcodes missing when the reveal token is spent" do
    IdentityOneTimeReveal.stub(:consume!, nil) do
      @harness.invoke(:show)
    end

    assert @harness.instance_variable_get(:@missing_recovery_passcodes)
    assert_empty @harness.instance_variable_get(:@recovery_passcodes)
  end
end

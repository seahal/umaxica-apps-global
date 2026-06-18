# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::App::Social::AuthenticationsControllerTest < ActionDispatch::IntegrationTest
  tests Acme::App::Social::AuthenticationsController

  setup do
    @request.host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    @commit_user = Client.create!(
      status_id: ClientStatus::VERIFIED_WITH_SIGN_UP,
      visibility_id: ClientVisibility::USER,
      birthdate: "2000-01-01",
    )
  end

  test "completion provisions the graph before session issuance" do
    graph_provisioned = false
    sign_up_flow_completed = false

    @controller.define_singleton_method(:establish_signed_in_session!) do |_resource, **_kwargs|
      raise "graph was not provisioned" unless graph_provisioned

      { status: :success, redirect_path: "/dashboard" }
    end
    @controller.define_singleton_method(:complete_acme_social_signup_flow!) do |_commit, _sign_in_result|
      raise "graph was not provisioned" unless graph_provisioned

      sign_up_flow_completed = true
    end

    commit = Struct.new(:user, :result, :pt, :identity, :existing_account).new(
      @commit_user,
      { "operation" => "signup", "actor_ref" => "flow-1" },
      nil,
      Struct.new(:provider).new("google_app"),
      false,
    )

    IdentitySocialCeremonyResult.stub(
      :decode,
      { "surface" => "app", "provider" => "google_app", "session_ref" => "session-1" },
    ) do
      IdentitySocialCeremonyContract.stub(
        :decode_untrusted_routing_payload,
        { "operation" => "signup", "session_ref" => "session-1" },
      ) do
        IdentitySocialCeremonyFinalCommitter.stub(:call!, commit) do
          IdentityGraphProvisioner.stub(:call!, ->(**) { graph_provisioned = true }) do
            post :completion, params: { id: "google_app", ri: "jp", social_ceremony_result: "signed-token" }
          end
        end
      end
    end

    assert_response :redirect
    assert_match %r{/dashboard\z}, response.location
    assert_predicate graph_provisioned, :itself
    assert_predicate sign_up_flow_completed, :itself
  end

  test "completion does not establish a session when graph provisioning fails" do
    session_started = false

    @controller.define_singleton_method(:establish_signed_in_session!) do |_resource, **_kwargs|
      session_started = true
      { status: :success, redirect_path: "/dashboard" }
    end

    commit = Struct.new(:user, :result, :pt, :identity, :existing_account).new(
      @commit_user,
      { "operation" => "signup", "actor_ref" => "flow-1" },
      nil,
      Struct.new(:provider).new("google_app"),
      false,
    )
    error = RuntimeError.new("graph boom")

    IdentitySocialCeremonyResult.stub(
      :decode,
      { "surface" => "app", "provider" => "google_app", "session_ref" => "session-1" },
    ) do
      IdentitySocialCeremonyContract.stub(
        :decode_untrusted_routing_payload,
        { "operation" => "signup", "session_ref" => "session-1" },
      ) do
        IdentitySocialCeremonyFinalCommitter.stub(:call!, commit) do
          IdentityGraphProvisioner.stub(:call!, ->(**) { raise error }) do
            raised =
              assert_raises(RuntimeError) do
                post(
                  :completion,
                  params: { id: "google_app", ri: "jp", social_ceremony_result: "signed-token" },
                )
              end

            assert_same error, raised
          end
        end
      end
    end

    assert_not session_started
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Up::ParticipantsControllerTest < ActionDispatch::IntegrationTest
  fixtures_none!

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    cookies["csrf_token"] = csrf_token_value
    ClientSignUpFlowStatus.ensure_defaults!
  end

  test "guard redirects direct access without a cycle to signup entry" do
    get sign_app_up_guard_url(ri: "jp"), headers: default_headers

    assert_redirected_to new_sign_app_sign_up_url(ri: "jp")
    assert_empty flash.to_hash
  end

  test "guard rejects ticket id without session binding" do
    ticket = create_ticket(status_id: ClientSignUpFlowStatus::CONTACT_VERIFIED, step: "contact_verified")

    get sign_app_up_guard_url(ri: "jp", sid: ticket.public_id), headers: default_headers

    assert_redirected_to new_sign_app_sign_up_url(ri: "jp")
    assert_empty flash.to_hash
  end

  test "guard redirects valid cycle to check without mutating signup state or durable rows" do
    ticket = create_ticket(status_id: ClientSignUpFlowStatus::CONTACT_VERIFIED, step: "contact_verified")
    before_attrs = guarded_ticket_attrs(ticket.reload)
    controller = build_guard_controller(ticket)

    assert_no_signup_guard_durable_changes do
      controller.show
    end

    assert_equal "/sign/up/check?ri=jp", controller.redirected_to
    assert_equal before_attrs, guarded_ticket_attrs(ticket.reload)
  end

  test "checkpoint show rejects ticket id without session binding" do
    ticket = create_ticket(status_id: ClientSignUpFlowStatus::GUARDRAIL_PENDING, step: "guardrail")

    get sign_app_up_check_url(ri: "jp", sid: ticket.public_id), headers: default_headers

    assert_redirected_to new_sign_app_sign_up_url(ri: "jp")
    assert_equal I18n.t("sign.app.registration.session_missing"), flash[:alert]
  end

  test "checkpoint update rejects direct access without a ticket" do
    patch sign_app_up_check_birthdate_url(ri: "jp"),
          params: { requirement: "birthdate" },
          headers: default_headers

    assert_response :not_found
    assert_equal "Not found", response.body
  end

  test "checkpoint destroy is routed for sign up cancellation" do
    route = Rails.application.routes.recognize_path(
      "http://#{host}/sign/up/check",
      method: :delete,
    )

    assert_equal "sign/app/up/checkpoints", route[:controller]
    assert_equal "destroy", route[:action]
  end

  private

  def create_ticket(attrs = {})
    ClientSignUpFlow.create!(
      {
        principal_id: nil,
        status_id: ClientSignUpFlowStatus::STARTED,
        step: "start",
        nonce_digest: ClientSignUpFlow.digest_nonce("nonce"),
        issued_at: Time.current,
        expires_at: 15.minutes.from_now,
        entry_method: "email",
      }.merge(attrs),
    )
  end

  def guarded_ticket_attrs(ticket)
    ticket.attributes.slice(
      "status_id",
      "state",
      "step",
      "principal_id",
      "pending_contact_type",
      "pending_contact_id",
      "completed_requirements",
    )
  end

  def assert_no_signup_guard_durable_changes(&)
    assert_no_difference("Client.count") do
      assert_no_difference("ClientGoogleIdentity.count") do
        assert_no_difference("ClientAppleIdentity.count") do
          assert_no_difference("ClientAccount.count") do
            assert_no_difference("Organization.count") do
              assert_no_difference("Avatar.count") do
                assert_no_difference("ClientToken.count", &)
              end
            end
          end
        end
      end
    end
  end

  def build_guard_controller(ticket)
    controller = Sign::App::Up::GuardsController.new
    locator = Struct.new(:current).new(ticket)
    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp") }
    controller.define_singleton_method(:path_target_value) { nil }
    controller.define_singleton_method(:signed_pt_param) { nil }
    controller.define_singleton_method(:signed_pt_token) { |path| path.presence && "signed-pt" }
    controller.define_singleton_method(:sign_up_flow_locator) { locator }
    controller.define_singleton_method(:sign_app_up_check_path) { |ri: nil, pt: nil|
      "/sign/up/check?ri=#{ri}#{pt ? "&pt=#{pt}" : ""}"
    }
    controller.define_singleton_method(:redirect_to) { |path, **_options| @redirected_to = path }
    controller.define_singleton_method(:redirected_to) { @redirected_to }
    controller
  end

  def default_headers
    { "Host" => host, "HTTPS" => "on", "X-CSRF-Token" => csrf_token_value }
  end
end

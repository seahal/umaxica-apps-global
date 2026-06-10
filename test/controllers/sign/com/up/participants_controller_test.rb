# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Up::ParticipantsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    cookies["csrf_token"] = csrf_token_value
  end

  test "guard redirects direct access without a cycle to signup entry" do
    get sign_com_sign_up_guard_email_url(ri: "jp"), headers: default_headers

    assert_redirected_to sign_com_sign_up_entrance_url(ri: "jp")
    assert_empty flash.to_hash
  end

  test "guard rejects ticket id without session binding" do
    ticket = create_ticket(
      status_id: VisitorSignUpFlowStatus::CHECKPOINT_PENDING,
      step: "checkpoint",
      completed_requirements: { "otp" => { "cleared" => true } },
    )

    get sign_com_sign_up_guard_email_url(ri: "jp", sid: ticket.public_id), headers: default_headers

    assert_redirected_to sign_com_sign_up_entrance_url(ri: "jp")
    assert_empty flash.to_hash
  end

  test "guard redirects valid cycle to check without mutating signup state or durable rows" do
    ticket = create_ticket(
      status_id: VisitorSignUpFlowStatus::CHECKPOINT_PENDING,
      step: "checkpoint",
      completed_requirements: { "otp" => { "cleared" => true } },
    )
    before_attrs = guarded_ticket_attrs(ticket.reload)
    controller = build_guard_controller(ticket)

    assert_no_signup_guard_durable_changes do
      controller.show
    end

    assert_equal "/sign/up/check/email/birthdate?ri=jp", controller.redirected_to
    assert_equal before_attrs, guarded_ticket_attrs(ticket.reload)
  end

  test "checkpoint show rejects ticket id without session binding" do
    ticket = create_ticket(status_id: VisitorSignUpFlowStatus::GUARDRAIL_PENDING, step: "guardrail")

    get sign_com_sign_up_check_email_birthdate_url(ri: "jp", sid: ticket.public_id), headers: default_headers

    assert_response :unprocessable_content
    assert_empty flash.to_hash
  end

  test "checkpoint update rejects direct access without a ticket" do
    patch sign_com_sign_up_check_email_birthdate_url(ri: "jp"),
          params: { requirement: "birthdate" },
          headers: default_headers

    assert_response :unprocessable_content
    assert_equal "ticket is required", response.body
  end

  test "checkpoint destroy is routed for sign up cancellation" do
    route = Rails.application.routes.recognize_path(
      "http://#{host}/sign/up/check/email/cancellation",
      method: :post,
    )

    assert_equal "sign/com/sign/up/check/email/cancellations", route[:controller]
    assert_equal "create", route[:action]
  end

  private

  def create_ticket(attrs = {})
    VisitorSignUpFlow.create!(
      {
        principal_id: nil,
        status_id: VisitorSignUpFlowStatus::STARTED,
        step: "start",
        nonce_digest: VisitorSignUpFlow.digest_nonce("nonce"),
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
    assert_no_difference("Visitor.count") do
      assert_no_difference("VisitorAccount.count") do
        assert_no_difference("Organization.count") do
          assert_no_difference("Avatar.count") do
            assert_no_difference("VisitorToken.count", &)
          end
        end
      end
    end
  end

  def build_guard_controller(ticket)
    controller = Sign::Com::Up::Guard::EmailsController.new
    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp") }
    controller.define_singleton_method(:session) do
      {
        com_sign_up_flow_locator: {
          "public_id" => ticket.public_id,
          "nonce" => "nonce",
        },
      }
    end
    controller.define_singleton_method(:path_target_value) { nil }
    controller.define_singleton_method(:signed_pt_param) { nil }
    controller.define_singleton_method(:signed_pt_token) { |path| path.presence && "signed-pt" }
    controller.define_singleton_method(:sign_com_sign_up_check_email_birthdate_path) { |ri: nil, pt: nil|
      "/sign/up/check/email/birthdate?ri=#{ri}#{pt ? "&pt=#{pt}" : ""}"
    }
    controller.define_singleton_method(:redirect_to) { |path, **_options| @redirected_to = path }
    controller.define_singleton_method(:redirected_to) { @redirected_to }
    controller
  end

  def default_headers
    { "Host" => host, "HTTPS" => "on", "X-CSRF-Token" => csrf_token_value }
  end
end

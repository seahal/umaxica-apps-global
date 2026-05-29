# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Configuration::EmailsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_identity_statuses, :operator_email_statuses, :operator_telephone_statuses

  setup do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = operators(:one)
    @token = OperatorToken.create!(staff: @staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    satisfy_staff_verification(@token)
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "configuration_email")

    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  def request_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-STAFF" => @staff.id,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end

  def with_prosopite_paused
    Prosopite.pause { yield }
  end

  test "should get index" do
    with_prosopite_paused { get sign_org_configuration_emails_url(ri: "jp"), headers: request_headers }

    assert_response :success
  end

  test "index displays verified status" do
    email = OperatorEmail.create!(
      address: "verified-staff@example.com",
      staff: @staff,
      staff_email_status_id: OperatorEmailStatus::VERIFIED,
    )

    with_prosopite_paused { get sign_org_configuration_emails_url(ri: "jp"), headers: request_headers }

    assert_response :success
    assert_includes response.body, "認証済み"
    assert_includes response.body, email.address
  end

  test "edit renders email preference toggles with current values" do
    email = OperatorEmail.create!(
      address: "preference-form-staff@example.com",
      staff: @staff,
      staff_email_status_id: OperatorEmailStatus::VERIFIED,
      promotional: false,
      notifiable: true,
    )

    with_prosopite_paused {
      get edit_sign_org_configuration_email_url(email.public_id, ri: "jp"), headers: request_headers
    }

    assert_response :success
    assert_select(
      "form[action=?][method=?] input[name=?][value=?]",
      sign_org_configuration_email_path(email.public_id, ri: "jp"),
      "post",
      "_method",
      "patch",
      count: 1,
    )
    assert_select "input[type=checkbox][name='staff_email[promotional]'][checked]", count: 0
    assert_select "input[type=checkbox][name='staff_email[notifiable]'][checked]", count: 1
    assert_select "input[name='cf-turnstile-response'][type='hidden']", count: 1
    assert_includes response.body, 'data-turnstile-mode-value="execute"'
  end

  test "update changes optional email preferences only" do
    email = OperatorEmail.create!(
      address: "preference-update-staff@example.com",
      staff: @staff,
      staff_email_status_id: OperatorEmailStatus::VERIFIED,
      promotional: true,
      notifiable: true,
      subscribable: true,
    )

    with_prosopite_paused do
      patch sign_org_configuration_email_url(email.public_id, ri: "jp"),
            params: {
              staff_email: {
                promotional: "0",
                notifiable: "0",
                subscribable: "0",
              },
            },
            headers: request_headers
    end

    assert_response :see_other
    assert_redirected_to edit_sign_org_configuration_email_url(email.public_id, ri: "jp")

    email.reload

    assert_not email.promotional
    assert_not email.notifiable
    assert email.subscribable
  end

  test "update requires step up" do
    staff = Operator.create!(status_id: OperatorIdentityStatus::ACTIVE)
    token = OperatorToken.create!(staff: staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    OperatorPasskey.create!(
      staff: staff,
      webauthn_id: "email-step-up-staff-passkey",
      public_key: "public-key",
      sign_count: 0,
    )
    email = OperatorEmail.create!(
      address: "step-up-staff@example.com",
      staff: staff,
      staff_email_status_id: OperatorEmailStatus::VERIFIED,
      promotional: true,
    )
    headers = {
      "Host" => @host,
      "X-TEST-CURRENT-STAFF" => staff.id,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    with_prosopite_paused do
      patch sign_org_configuration_email_url(email.public_id, ri: "jp"),
            params: { staff_email: { promotional: "0", notifiable: "1" } },
            headers: headers
    end

    assert_response :unauthorized
    assert_equal Verification::Base::STEP_UP_REQUIRED_MESSAGE, response.body
    assert email.reload.promotional
  end

  test "update rejects when turnstile fails" do
    email = OperatorEmail.create!(
      address: "turnstile-failure-staff@example.com",
      staff: @staff,
      staff_email_status_id: OperatorEmailStatus::VERIFIED,
      promotional: true,
      notifiable: true,
    )
    CloudflareTurnstile.test_validation_response = { "success" => false }

    with_prosopite_paused do
      patch sign_org_configuration_email_url(email.public_id, ri: "jp"),
            params: { staff_email: { promotional: "0", notifiable: "0" } },
            headers: request_headers
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("turnstile_error")
    assert email.reload.promotional
    assert email.notifiable
  end

  test "update does not change another staff member's email" do
    other_staff = Operator.create!(status_id: OperatorIdentityStatus::ACTIVE)
    email = OperatorEmail.create!(
      address: "other-staff-preference@example.com",
      staff: other_staff,
      staff_email_status_id: OperatorEmailStatus::VERIFIED,
      promotional: true,
      notifiable: true,
    )

    assert_no_changes -> { email.reload.attributes.slice("promotional", "notifiable") } do
      with_prosopite_paused do
        patch sign_org_configuration_email_url(email.public_id, ri: "jp"),
              params: { staff_email: { promotional: "0", notifiable: "0" } },
              headers: request_headers
      end
    end

    assert_response :not_found
  end

  test "destroy removes email when not last method" do
    email1 = OperatorEmail.create!(
      address: "delete-staff1@example.com",
      staff: @staff,
      staff_email_status_id: OperatorEmailStatus::VERIFIED,
    )
    OperatorEmail.create!(
      address: "delete-staff2@example.com",
      staff: @staff,
      staff_email_status_id: OperatorEmailStatus::VERIFIED,
    )

    assert_difference("OperatorEmail.count", -1) do
      with_prosopite_paused { delete sign_org_configuration_email_url(email1, ri: "jp"), headers: request_headers }
    end

    assert_response :see_other
  end

  test "destroy blocks removing an undeletable email" do
    email = OperatorEmail.create!(
      address: "protected-staff@example.com",
      staff: @staff,
      staff_email_status_id: OperatorEmailStatus::VERIFIED,
      undeletable: true,
    )
    OperatorEmail.create!(
      address: "other-staff@example.com",
      staff: @staff,
      staff_email_status_id: OperatorEmailStatus::VERIFIED,
    )

    assert_no_difference("OperatorEmail.count") do
      with_prosopite_paused { delete sign_org_configuration_email_url(email, ri: "jp"), headers: request_headers }
    end

    assert_redirected_to sign_org_configuration_emails_url(ri: "jp")
    assert_equal I18n.t("sign.org.configuration.email.destroy.protected"), flash[:alert]
  end
end

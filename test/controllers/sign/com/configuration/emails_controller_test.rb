# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Configuration::EmailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @visitor = create_verified_visitor_with_email(
      email_address: "config-#{SecureRandom.hex(4)}@example.com",
    )
    @visitor.visitor_telephones.create!(
      number: "+15550001110",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    @headers = as_visitor_headers(@visitor, host: @host)
    @token = VisitorToken.find_by!(public_id: @headers["X-TEST-SESSION-PUBLIC-ID"])
    satisfy_visitor_verification(@token)
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "configuration_email")

    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  def with_prosopite_paused
    Prosopite.pause { yield }
  end

  test "should get index" do
    with_prosopite_paused { get sign_com_configuration_emails_url(ri: "jp"), headers: @headers }

    assert_response :success
  end

  test "edit renders email preference toggles with current values" do
    email = VisitorEmail.create!(
      visitor: @visitor,
      address: "preference-form-com@example.com",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      confirm_policy: true,
      promotional: false,
      notifiable: true,
    )

    with_prosopite_paused { get edit_sign_com_configuration_email_url(email.public_id, ri: "jp"), headers: @headers }

    assert_response :success
    assert_select(
      "form[action=?][method=?] input[name=?][value=?]",
      sign_com_configuration_email_path(email.public_id, ri: "jp"),
      "post",
      "_method",
      "patch",
      count: 1,
    )
    assert_select "input[type=checkbox][name='visitor_email[promotional]'][checked]", count: 0
    assert_select "input[type=checkbox][name='visitor_email[notifiable]'][checked]", count: 1
    assert_select "input[name='cf-turnstile-response'][type='hidden']", count: 1
    assert_includes response.body, 'data-turnstile-mode-value="execute"'
  end

  test "update changes optional email preferences only" do
    email = VisitorEmail.create!(
      visitor: @visitor,
      address: "preference-update-com@example.com",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      confirm_policy: true,
      promotional: true,
      notifiable: true,
      subscribable: true,
    )

    with_prosopite_paused do
      patch sign_com_configuration_email_url(email.public_id, ri: "jp"),
            params: {
              visitor_email: {
                promotional: "0",
                notifiable: "0",
                subscribable: "0",
              },
            },
            headers: @headers
    end

    assert_response :see_other
    assert_redirected_to edit_sign_com_configuration_email_url(email.public_id, ri: "jp")

    email.reload

    assert_not email.promotional
    assert_not email.notifiable
    assert email.subscribable
  end

  test "update requires step up" do
    visitor = create_verified_visitor_with_email(
      email_address: "step-up-com-#{SecureRandom.hex(4)}@example.com",
    )
    visitor.visitor_telephones.create!(
      number: "+1555#{SecureRandom.random_number(10**7).to_s.rjust(7, "0")}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    visitor.visitor_passkeys.create!(
      webauthn_id: "email-step-up-com-passkey-#{SecureRandom.hex(4)}",
      public_key: "public-key",
      description: "Passkey",
      status_id: VisitorPasskeyStatus::ACTIVE,
    )
    headers = as_visitor_headers(visitor, host: @host)
    email = visitor.visitor_emails.find_by!(
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )

    with_prosopite_paused do
      patch sign_com_configuration_email_url(email.public_id, ri: "jp"),
            params: { visitor_email: { promotional: "0", notifiable: "1" } },
            headers: headers
    end

    assert_response :unauthorized
    assert_equal Verification::Base::STEP_UP_REQUIRED_MESSAGE, response.body
    assert email.reload.promotional
  end

  test "update rejects when turnstile fails" do
    email = VisitorEmail.create!(
      visitor: @visitor,
      address: "turnstile-failure-com@example.com",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      confirm_policy: true,
      promotional: true,
      notifiable: true,
    )
    CloudflareTurnstile.test_validation_response = { "success" => false }

    with_prosopite_paused do
      patch sign_com_configuration_email_url(email.public_id, ri: "jp"),
            params: { visitor_email: { promotional: "0", notifiable: "0" } },
            headers: @headers
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("turnstile_error")
    assert email.reload.promotional
    assert email.notifiable
  end

  test "update does not change another visitor's email" do
    other_visitor = create_verified_visitor_with_email(
      email_address: "other-visitor-#{SecureRandom.hex(4)}@example.com",
    )
    email = other_visitor.visitor_emails.find_by!(
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )

    assert_no_changes -> { email.reload.attributes.slice("promotional", "notifiable") } do
      with_prosopite_paused do
        patch sign_com_configuration_email_url(email.public_id, ri: "jp"),
              params: { visitor_email: { promotional: "0", notifiable: "0" } },
              headers: @headers
      end
    end

    assert_response :not_found
  end

  test "destroy removes email when not last method" do
    email = VisitorEmail.create!(
      visitor: @visitor,
      address: "delete-com@example.com",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      confirm_policy: true,
    )

    assert_difference("VisitorEmail.count", -1) do
      with_prosopite_paused { delete sign_com_configuration_email_url(email, ri: "jp"), headers: @headers }
    end

    assert_response :see_other
  end

  test "destroy blocks removing an undeletable email" do
    email = VisitorEmail.create!(
      visitor: @visitor,
      address: "protected-com@example.com",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      confirm_policy: true,
      undeletable: true,
    )

    assert_no_difference("VisitorEmail.count") do
      with_prosopite_paused { delete sign_com_configuration_email_url(email, ri: "jp"), headers: @headers }
    end

    assert_redirected_to sign_com_configuration_emails_url(ri: "jp")
    assert_equal I18n.t("sign.app.configuration.email.destroy.protected"), flash[:alert]
  end
end

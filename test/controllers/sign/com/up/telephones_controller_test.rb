# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Up::TelephonesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  setup do
    host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    cookies["csrf_token"] = csrf_token_value
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
    Prosopite.pause do
      [1, 2, 3].each { |id| VisitorStatus.find_or_create_by!(id: id) }
      [0, 1, 2, 3].each { |id| VisitorVisibility.find_or_create_by!(id: id) }
      [
        VisitorTelephoneStatus::UNVERIFIED,
        VisitorTelephoneStatus::VERIFIED,
        VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
        VisitorTelephoneStatus::VERIFIED_WITH_SIGN_UP,
      ].each { |id| VisitorTelephoneStatus.find_or_create_by!(id: id) }
      VisitorTokenDbscStatus.ensure_defaults!
      VisitorTokenStatus::DEFAULTS.each do |id|
        VisitorTokenStatus.find_or_create_by!(id: id)
      end
    end
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "should get new" do
    get new_sign_com_up_telephone_url(ri: "jp"), headers: default_headers

    assert_response :success
  end

  test "new rejects when visitor is already logged in" do
    visitor = create_verified_visitor_with_email(email_address: "logged-in-com-up-telephone@example.com")
    visitor.visitor_telephones.create!(
      number: "+15550002222",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )

    get new_sign_com_up_telephone_url(ri: "jp"),
        headers: as_visitor_headers(visitor, host: host)

    assert_response :redirect
    assert_redirected_to acme_com_dashboard_url(ri: "jp", host: ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost"))
  end

  test "create rejects when visitor is already logged in" do
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)

    assert_no_difference("VisitorTelephone.count") do
      post sign_com_up_telephone_url(ri: "jp"),
           params: {
             visitor_telephone: {
               raw_number: "+819012300099",
               confirm_policy: "1",
               confirm_using_mfa: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: as_visitor_headers(visitor, host: host)
    end

    assert_response :redirect
    uri = URI.parse(response.location)

    assert_equal "/settings/telephones/registration/new?ri=jp", uri.request_uri
  end

  test "create redirects to edit and creates pending visitor telephone" do
    assert_difference("Visitor.count", 1) do
      assert_difference("VisitorTelephone.count", 1) do
        post sign_com_up_telephone_url(ri: "jp"),
             params: {
               visitor_telephone: {
                 raw_number: "+819012300001",
                 confirm_policy: "1",
                 confirm_using_mfa: "1",
               },
               "cf-turnstile-response": "test",
             },
             headers: default_headers
      end
    end

    assert_response :redirect
    telephone = VisitorTelephone.order(:created_at).last

    assert_equal VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP, telephone.visitor_telephone_status_id
    assert_includes response.location, "/sign/up/telephone/edit"
  end

  test "update routes to guardrail without signup audits or client account" do
    post sign_com_up_telephone_url(ri: "jp"),
         params: {
           visitor_telephone: {
             raw_number: "+819012300010",
             confirm_policy: "1",
             confirm_using_mfa: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    telephone = VisitorTelephone.order(:created_at).last
    code = otp_code_for(telephone)

    assert_no_difference("ClientChronicle.count") do
      patch sign_com_up_telephone_url(ri: "jp"),
            params: { visitor_telephone: { pass_code: code } },
            headers: default_headers
    end

    visitor = telephone.reload.visitor
    cycle = VisitorSignUpFlow.find_by!(public_id: session.dig(:com_sign_up_flow_locator, "public_id"))

    assert_redirected_to sign_com_up_guardrail_path(ri: "jp")
    assert_nil visitor.rp_account
    assert_equal VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP, telephone.visitor_telephone_status_id
    assert session.dig(:visitor_telephone_registration, "otp_verified")
    assert_equal visitor.id, cycle.principal_id
    assert_equal "telephone", cycle.pending_contact_type
    assert_equal telephone.id, cycle.pending_contact_id
    assert_equal "contact_verified", cycle.step
    assert_equal 0,
                 ClientChronicle.where(
                   event_id: ClientChronicleEvent::SIGNED_UP_WITH_TELEPHONE,
                   subject_id: visitor.id.to_s,
                   subject_type: "Visitor",
                 ).count
    assert_equal 0,
                 ClientChronicle.where(
                   event_id: ClientChronicleEvent::LOGGED_IN,
                   subject_id: visitor.id.to_s,
                   subject_type: "Visitor",
                 ).count
  end

  test "create with invalid telephone fails" do
    post sign_com_up_telephone_url(ri: "jp"),
         params: {
           visitor_telephone: {
             raw_number: "not-a-phone",
             confirm_policy: "1",
             confirm_using_mfa: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :unprocessable_content
  end

  test "existing telephone redirects to sign in without sign up cycle" do
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    existing_telephone = VisitorTelephone.create!(
      visitor: visitor,
      raw_number: "+819012300011",
      confirm_policy: "1",
      confirm_using_mfa: "1",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )

    assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
      assert_no_difference("VisitorTelephone.count") do
        post sign_com_up_telephone_url(ri: "jp"),
             params: {
               visitor_telephone: {
                 raw_number: "+819012300011",
                 confirm_policy: "1",
                 confirm_using_mfa: "1",
               },
               "cf-turnstile-response": "test",
             },
             headers: default_headers
      end
    end

    assert_response :redirect
    assert_nil session[:com_sign_up_flow_locator]
    job_args = enqueued_jobs.last[:args].first
    body = Outbound::SensitivePayload.decrypt_sms_body(job_args.fetch("encrypted_body"))
    sent_code = body[/\d{6}/]

    assert_equal "Verification code", job_args.fetch("title")
    assert_match(/\A\d{6}\z/, sent_code)
    assert_not_includes job_args.fetch("title"), sent_code
    assert_not_includes job_args.inspect, sent_code

    code = otp_code_for(existing_telephone.reload)

    assert_no_difference("ClientChronicle.count") do
      patch sign_com_up_telephone_url(ri: "jp"),
            params: { visitor_telephone: { pass_code: code } },
            headers: default_headers
    end

    assert_redirected_to new_sign_com_sign_in_path(ri: "jp")
    assert_nil session[:visitor_telephone_registration]
    assert_nil session[:com_sign_up_flow_locator]
    assert_equal VisitorTelephoneStatus::VERIFIED, existing_telephone.reload.visitor_telephone_status_id
  end

  test "create renders unprocessable when visitor_telephone param missing" do
    assert_enqueued_jobs 0, only: Outbound::SmsDeliveryJob do
      assert_no_difference("Visitor.count") do
        assert_no_difference("VisitorTelephone.count") do
          post sign_com_up_telephone_url(ri: "jp"),
               params: { "cf-turnstile-response": "test" },
               headers: default_headers
        end
      end
    end

    assert_response :unprocessable_content
  end

  test "create with turnstile failure returns unprocessable content" do
    CloudflareTurnstile.test_validation_response = { "success" => false }

    post sign_com_up_telephone_url(ri: "jp"),
         params: {
           visitor_telephone: {
             raw_number: "+819012300002",
             confirm_policy: "1",
             confirm_using_mfa: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :unprocessable_content
  end

  test "update with missing visitor_telephone params renders unprocessable" do
    post sign_com_up_telephone_url(ri: "jp"),
         params: {
           visitor_telephone: {
             raw_number: "+819012300098",
             confirm_policy: "1",
             confirm_using_mfa: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    VisitorTelephone.order(:created_at).last

    patch sign_com_up_telephone_url(ri: "jp"), headers: default_headers

    assert_response :unprocessable_content
  end

  test "update with invalid OTP does not create session" do
    post sign_com_up_telephone_url(ri: "jp"),
         params: {
           visitor_telephone: {
             raw_number: "+819012300097",
             confirm_policy: "1",
             confirm_using_mfa: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    telephone = VisitorTelephone.order(:created_at).last

    assert_no_difference("VisitorToken.count") do
      patch sign_com_up_telephone_url(ri: "jp"),
            params: { visitor_telephone: { pass_code: "000000" } },
            headers: default_headers
    end

    assert_response :unprocessable_content
    assert_equal 1, telephone.reload.otp_attempts_count
  end

  test "update locks after max failed OTP attempts" do
    post sign_com_up_telephone_url(ri: "jp"),
         params: {
           visitor_telephone: {
             raw_number: "+819012300096",
             confirm_policy: "1",
             confirm_using_mfa: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    telephone = VisitorTelephone.order(:created_at).last

    Prosopite.pause do
      Telephone::MAX_OTP_ATTEMPTS.times do
        patch sign_com_up_telephone_url(ri: "jp"),
              params: { visitor_telephone: { pass_code: "000000" } },
              headers: default_headers
      end
    end

    assert_redirected_to new_sign_com_up_telephone_path(ri: "jp")
    assert_predicate telephone.reload, :locked?
    assert_nil session[:visitor_telephone_registration]
  end

  test "update without a valid session redirects to new" do
    VisitorTelephone.create!(
      visitor: Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR),
      raw_number: "+819012300003",
      confirm_policy: "1",
      confirm_using_mfa: "1",
      visitor_telephone_status_id: VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
      otp_expires_at: 5.minutes.from_now,
    )

    patch sign_com_up_telephone_url(ri: "jp"),
          params: { visitor_telephone: { pass_code: "123456" } },
          headers: default_headers

    assert_redirected_to new_sign_com_up_telephone_path(ri: "jp")
  end

  test "create rejects duplicate unverified telephone inside overwrite window" do
    post sign_com_up_telephone_url(ri: "jp"),
         params: {
           visitor_telephone: {
             raw_number: "+819012300004",
             confirm_policy: "1",
             confirm_using_mfa: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    first_public_id = VisitorTelephone.order(:created_at).last.public_id
    first_telephone = VisitorTelephone.find_by!(public_id: first_public_id)
    first_visitor = first_telephone.visitor

    assert_no_difference("VisitorTelephone.count") do
      assert_no_difference("Visitor.count") do
        post sign_com_up_telephone_url(ri: "jp"),
             params: {
               visitor_telephone: {
                 raw_number: "+819012300004",
                 confirm_policy: "1",
                 confirm_using_mfa: "1",
               },
               "cf-turnstile-response": "test",
             },
             headers: default_headers
      end
    end

    assert_response :too_many_requests
    assert VisitorTelephone.exists?(first_telephone.id)
    assert Visitor.exists?(first_visitor.id)
  end

  test "create after overwrite window replaces duplicate unverified telephone" do
    post sign_com_up_telephone_url(ri: "jp"),
         params: {
           visitor_telephone: {
             raw_number: "+819012300005",
             confirm_policy: "1",
             confirm_using_mfa: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    first_public_id = VisitorTelephone.order(:created_at).last.public_id
    first_telephone = VisitorTelephone.find_by!(public_id: first_public_id)
    first_visitor = first_telephone.visitor

    travel Common::OtpPolicy::REREGISTRATION_OVERWRITE_WINDOW + 1.second do
      post sign_com_up_telephone_url(ri: "jp"),
           params: {
             visitor_telephone: {
               raw_number: "+819012300005",
               confirm_policy: "1",
               confirm_using_mfa: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    assert_response :redirect
    assert_not VisitorTelephone.exists?(first_telephone.id)
    assert_not Visitor.exists?(first_visitor.id)
    new_public_id = VisitorTelephone.order(:created_at).last.public_id

    assert VisitorTelephone.exists?(public_id: new_public_id)
  end

  private

  def default_headers
    { "Host" => host, "HTTPS" => "on", "X-CSRF-Token" => csrf_token_value }
  end

  def host
    ENV["ID_CORPORATE_URL"] || "id.com.localhost"
  end

  def otp_code_for(telephone)
    otp_data = telephone.get_otp
    ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter])
  end
end

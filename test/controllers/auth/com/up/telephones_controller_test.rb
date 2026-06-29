# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class Auth::Com::Sign::Up::TelephonesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  setup do
    host! ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")
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
    get new_auth_com_sign_up_telephone_url(ri: "jp"), headers: default_headers

    assert_response :success
  end

  test "new rejects when visitor is already logged in" do
    visitor = create_verified_visitor_with_email(email_address: "logged-in-com-up-telephone@example.com")
    visitor.visitor_telephones.create!(
      number: "+15550002222",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )

    get new_auth_com_sign_up_telephone_url(ri: "jp"),
        headers: as_visitor_headers(visitor, host: host)

    assert_response :redirect
    assert_redirected_to auth_com_dashboard_url(
      ri: "jp",
      host: ENV.fetch(
        "PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost",
      ),
    )
  end

  test "create rejects when visitor is already logged in" do
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)

    assert_no_difference("VisitorTelephone.count") do
      post auth_com_sign_up_telephone_url(ri: "jp"),
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
        post auth_com_sign_up_telephone_url(ri: "jp"),
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
    assert_includes response.location, "/sign/up/check/telephone/otp"
  end

  test "edit renders authentication code copy" do
    post auth_com_sign_up_telephone_url(ri: "jp"),
         params: {
           visitor_telephone: {
             raw_number: "+819012300002",
             confirm_policy: "1",
             confirm_using_mfa: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    get auth_com_sign_up_check_telephone_otp_url(ri: "jp"), headers: default_headers

    assert_response :success
    assert_select "h1", text: I18n.t("sign.app.registration.telephone.edit.page_title")
    assert_select "label", text: I18n.t("sign.app.registration.telephone.edit.code_label")
    assert_select "input[placeholder=?]", I18n.t("sign.app.registration.telephone.edit.code_placeholder")
    assert_select "input[type=submit][value=?]", I18n.t("sign.app.registration.telephone.edit.submit")
    assert_includes response.body, "電話番号"
    assert_includes response.body, "SMS"
    assert_includes response.body, I18n.t("sign.app.registration.telephone.edit.delivery_help")
  end

  test "create with invalid telephone fails" do
    post auth_com_sign_up_telephone_url(ri: "jp"),
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

  test "create renders unprocessable when visitor_telephone param missing" do
    assert_enqueued_jobs 0, only: Outbound::SmsDeliveryJob do
      assert_no_difference("Visitor.count") do
        assert_no_difference("VisitorTelephone.count") do
          post auth_com_sign_up_telephone_url(ri: "jp"),
               params: { "cf-turnstile-response": "test" },
               headers: default_headers
        end
      end
    end

    assert_response :unprocessable_content
  end

  test "create with turnstile failure returns unprocessable content" do
    CloudflareTurnstile.test_validation_response = { "success" => false }

    post auth_com_sign_up_telephone_url(ri: "jp"),
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

  test "create rejects duplicate unverified telephone inside overwrite window" do
    post auth_com_sign_up_telephone_url(ri: "jp"),
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
        post auth_com_sign_up_telephone_url(ri: "jp"),
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
    post auth_com_sign_up_telephone_url(ri: "jp"),
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

    travel CommonOtpPolicy::REREGISTRATION_OVERWRITE_WINDOW + 1.second do
      post auth_com_sign_up_telephone_url(ri: "jp"),
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
    ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")
  end

  def otp_code_for(telephone)
    otp_data = telephone.get_otp
    ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter])
  end
end

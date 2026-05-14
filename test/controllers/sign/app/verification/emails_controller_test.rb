# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::App::Verification::EmailsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users

  setup do
    @previous_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = users(:one)
    @headers = as_user_headers(@user, host: @host)
    @token = UserToken.find_by!(public_id: @headers["X-TEST-SESSION-PUBLIC-ID"])
    @active_token = @token
    UserEmail.create!(
      user: @user,
      address: "verified-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: UserEmailStatus::VERIFIED,
      otp_private_key: "otp_private_key",
      otp_counter: "0",
    )
  end

  teardown do
    Rails.cache = @previous_cache_store
  end

  test "new sends otp and redirects to edit" do
    return_to = Base64.urlsafe_encode64(sign_app_configuration_emails_path(ri: "jp"))

    StepUp::AvailableMethods.stub(:call, [:email_otp]) do
      Email::App::RegistrationMailer.stub(:with, OpenStruct.new(create: OpenStruct.new(deliver_later: true))) do
        get sign_app_verification_url(scope: "configuration_email", return_to: return_to, ri: "jp"),
            headers: @headers

        assert_response :success

        get new_sign_app_verification_email_url(ri: "jp"), headers: @headers

        assert_response :redirect

        assert_match %r{/verification/emails/.+/edit}, response.location

        follow_redirect!(headers: @headers)

        assert_response :success
      end
    end
  end

  test "email selection from verification page reaches otp entry page" do
    return_to = Base64.urlsafe_encode64(
      edit_sign_app_configuration_email_path(
        @user.user_emails.last.public_id,
        ri: "jp",
      ),
    )

    StepUp::AvailableMethods.stub(:call, [:email_otp]) do
      get sign_app_verification_url(scope: "configuration_email", rt: return_to, ri: "jp"),
          headers: @headers

      assert_response :success

      assert_select(
        "a[href=?]",
        new_sign_app_verification_email_path(ri: "jp", scope: "configuration_email", rt: return_to),
      )

      assert_enqueued_emails 1 do
        get new_sign_app_verification_email_url(
          ri: "jp",
          scope: "configuration_email",
          rt: return_to,
        ), headers: @headers
      end

      assert_response :redirect
      follow_redirect!(headers: @headers)

      assert_response :success
      assert_select "input[name='verification[code]']"
    end
  end

  test "new enqueues otp email while request is on readonly role" do
    @previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :solid_queue
    return_to = Base64.urlsafe_encode64(
      edit_sign_app_configuration_email_path(
        @user.user_emails.last.public_id,
        ri: "jp",
      ),
    )

    StepUp::AvailableMethods.stub(:call, [:email_otp]) do
      assert_difference -> { SolidQueue::Job.where(class_name: "ActionMailer::MailDeliveryJob").count }, 1 do
        ActiveRecord::Base.connected_to(role: :reading, prevent_writes: true) do
          get(
            new_sign_app_verification_email_url(
              ri: "jp",
              scope: "configuration_email",
              rt: return_to,
            ), headers: @headers,
          )
        end
      end
    end

    assert_response :redirect
  ensure
    ActiveJob::Base.queue_adapter = @previous_adapter if @previous_adapter
  end

  test "new sends otp for email verified during signup" do
    @user.user_emails.update_all(user_email_status_id: UserEmailStatus::VERIFIED_WITH_SIGN_UP)
    return_to = Base64.urlsafe_encode64(sign_app_configuration_emails_path(ri: "jp"))

    StepUp::AvailableMethods.stub(:call, [:email_otp]) do
      get sign_app_verification_url(scope: "configuration_email", return_to: return_to, ri: "jp"),
          headers: @headers

      assert_response :success

      assert_enqueued_emails 1 do
        get new_sign_app_verification_email_url(ri: "jp"), headers: @headers
      end

      assert_response :redirect
      assert_match %r{/verification/emails/.+/edit}, response.location
    end
  end

  test "new keeps scope and return_to in form hidden fields" do
    return_to = Base64.urlsafe_encode64(sign_app_configuration_emails_path(ri: "jp"))

    StepUp::AvailableMethods.stub(:call, [:email_otp]) do
      get new_sign_app_verification_email_url(
        ri: "jp",
        scope: "configuration_email",
        return_to: return_to,
      ), headers: @headers

      assert_response :redirect
      assert_match %r{/verification/emails/.+/edit}, response.location
    end
  end

  test "new restores reauth session from scope and rt query parameters" do
    return_to = Base64.urlsafe_encode64(sign_app_configuration_emails_path(ri: "jp"))

    StepUp::AvailableMethods.stub(:call, [:email_otp]) do
      assert_enqueued_emails 1 do
        get new_sign_app_verification_email_url(
          ri: "jp",
          scope: "configuration_email",
          rt: return_to,
        ), headers: @headers
      end

      assert_response :redirect
      assert_match %r{/verification/emails/.+/edit}, response.location
    end
  end

  test "new resends otp when otp cache is already active" do
    return_to = Base64.urlsafe_encode64(sign_app_configuration_emails_path(ri: "jp"))

    get sign_app_verification_url(scope: "configuration_email", rt: return_to, ri: "jp"),
        headers: @headers

    assert_response :success
    cache_email_otp!

    StepUp::AvailableMethods.stub(:call, [:email_otp]) do
      assert_enqueued_emails 1 do
        get new_sign_app_verification_email_url(
          ri: "jp",
          scope: "configuration_email",
          rt: return_to,
        ), headers: @headers
      end
    end

    assert_response :redirect
    assert_match %r{/verification/emails/.+/edit}, response.location
  end

  test "edit sends otp when nonce is valid but otp cache is missing" do
    return_to = Base64.urlsafe_encode64(sign_app_configuration_emails_path(ri: "jp"))

    get sign_app_verification_url(scope: "configuration_email", rt: return_to, ri: "jp"),
        headers: @headers

    assert_response :success

    nonce = SecureRandom.urlsafe_base64(16)
    cache_email_nonce!(nonce)

    StepUp::AvailableMethods.stub(:call, []) do
      assert_enqueued_emails 1 do
        get edit_sign_app_verification_email_url(nonce, ri: "jp"), headers: @headers
      end
    end

    assert_response :success
    assert_select "input[name='verification[code]']"
  end

  test "edit does not resend otp when otp cache is already active" do
    return_to = Base64.urlsafe_encode64(sign_app_configuration_emails_path(ri: "jp"))

    get sign_app_verification_url(scope: "configuration_email", rt: return_to, ri: "jp"),
        headers: @headers

    assert_response :success

    nonce = SecureRandom.urlsafe_base64(16)
    cache_email_nonce!(nonce)
    cache_email_otp!

    StepUp::AvailableMethods.stub(:call, []) do
      assert_enqueued_emails 0 do
        get edit_sign_app_verification_email_url(nonce, ri: "jp"), headers: @headers
      end
    end

    assert_response :success
    assert_select "input[name='verification[code]']"
  end

  test "update verifies otp and redirects to return_to" do
    return_to = Base64.urlsafe_encode64(sign_app_configuration_emails_path(ri: "jp"))

    StepUp::AvailableMethods.stub(:call, [:email_otp]) do
      Email::App::RegistrationMailer.stub(:with, OpenStruct.new(create: OpenStruct.new(deliver_later: true))) do
        get sign_app_verification_url(scope: "configuration_email", return_to: return_to, ri: "jp"),
            headers: @headers

        assert_response :success

        get new_sign_app_verification_email_url(ri: "jp"), headers: @headers

        assert_response :redirect
        nonce = response.location[%r{/verification/emails/([^/?]+)/edit}, 1]
        cache_email_nonce!(nonce)

        with_email_nonce_stub(true) do
          with_verify_email_otp_stub(true) do
            patch sign_app_verification_email_url(nonce, ri: "jp"),
                  params: { verification: { code: "123456" } },
                  headers: @headers

            assert_response :redirect
            assert_redirected_to sign_app_configuration_emails_url(ri: "jp")
            assert_nil @token.reload.reauth_session
            assert_nil Rails.cache.read(email_otp_cache_key_for_id(@reauth_session_id))
          end
        end
      end
    end
  end

  test "invalid otp keeps back link from reauth session when request params are missing" do
    return_to = Base64.urlsafe_encode64(sign_app_configuration_emails_path(ri: "jp"))

    get sign_app_verification_url(scope: "configuration_email", rt: return_to, ri: "jp"),
        headers: @headers

    assert_response :success

    nonce = SecureRandom.urlsafe_base64(16)
    cache_email_nonce!(nonce)

    patch sign_app_verification_email_url(nonce, ri: "jp"),
          params: { verification: { code: "000000" } },
          headers: @headers

    assert_response :unprocessable_content
    assert_select(
      "a[href=?]",
      sign_app_verification_path(ri: "jp", scope: "configuration_email", return_to: return_to),
      text: I18n.t("sign.app.verification.edit.back"),
    )
    assert_select(
      "input[name='verification[return_to]'][value=?]",
      return_to,
    )
  end

  test "resend sends a new otp and returns to edit page" do
    return_to = Base64.urlsafe_encode64(sign_app_configuration_emails_path(ri: "jp"))

    get sign_app_verification_url(scope: "configuration_email", rt: return_to, ri: "jp"),
        headers: @headers

    assert_response :success

    nonce = SecureRandom.urlsafe_base64(16)
    cache_email_nonce!(nonce)

    assert_enqueued_emails 1 do
      post resend_sign_app_verification_email_url(
        nonce,
        ri: "jp",
        scope: "configuration_email",
        return_to: return_to,
      ), headers: @headers
    end

    assert_response :redirect
    assert_redirected_to edit_sign_app_verification_email_url(
      nonce,
      ri: "jp",
      scope: "configuration_email",
      return_to: return_to,
    )
    assert_equal I18n.t("otp.resend.sent"), flash[:notice]
    assert Rails.cache.exist?(email_otp_cache_key)
  end

  test "resend is rate limited" do
    return_to = Base64.urlsafe_encode64(sign_app_configuration_emails_path(ri: "jp"))

    get sign_app_verification_url(scope: "configuration_email", rt: return_to, ri: "jp"),
        headers: @headers

    assert_response :success

    nonce = SecureRandom.urlsafe_base64(16)
    cache_email_nonce!(nonce)

    assert_enqueued_emails 1 do
      post resend_sign_app_verification_email_url(nonce, ri: "jp"), headers: @headers
    end

    assert_enqueued_emails 0 do
      post resend_sign_app_verification_email_url(nonce, ri: "jp"), headers: @headers
    end

    assert_response :redirect
    assert_equal I18n.t("otp.resend.too_soon"), flash[:alert]
  end

  test "step up flow from configuration emails returns to original page" do
    stale_token = UserToken.create!(user_id: @user.id, created_at: 20.minutes.ago, updated_at: 20.minutes.ago)
    stale_headers = @headers.merge("X-TEST-SESSION-PUBLIC-ID" => stale_token.public_id)
    @active_token = stale_token
    email = @user.user_emails.where(user_email_status_id: AuthMethodGuard::VERIFIED_EMAIL_STATUSES).first

    StepUp::AvailableMethods.stub(:call, [:email_otp]) do
      get edit_sign_app_configuration_email_url(email.public_id, ri: "jp"), headers: stale_headers

      assert_response :redirect

      query = Rack::Utils.parse_nested_query(URI(response.location).query)
      scope = query["scope"]
      return_to = query["rt"] || query["return_to"]

      assert_equal "configuration_email", scope
      assert_predicate return_to, :present?

      get sign_app_verification_url(scope: scope, rt: return_to, ri: "jp"), headers: stale_headers

      assert_response :success

      Email::App::RegistrationMailer.stub(:with, OpenStruct.new(create: OpenStruct.new(deliver_later: true))) do
        post sign_app_verification_emails_url(ri: "jp"),
             params: { verification: { scope: scope, rt: return_to } },
             headers: stale_headers
      end

      assert_response :redirect
      nonce = response.location[%r{/verification/emails/([^/?]+)/edit}, 1]

      assert_predicate nonce, :present?
      cache_email_nonce!(nonce)

      with_email_nonce_stub(true) do
        with_verify_email_otp_stub(true) do
          patch sign_app_verification_email_url(nonce, ri: "jp"),
                params: { verification: { code: "123456", scope: scope, rt: return_to } },
                headers: stale_headers
        end
      end

      assert_response :redirect
      assert_redirected_to edit_sign_app_configuration_email_url(email.public_id, ri: "jp")
    end
  end

  test "create restores reauth session only when scope and return_to are present" do
    StepUp::AvailableMethods.stub(:call, [:email_otp]) do
      Email::App::RegistrationMailer.stub(:with, OpenStruct.new(create: OpenStruct.new(deliver_later: true))) do
        post sign_app_verification_emails_url(ri: "jp"),
             params: { verification: { scope: "", return_to: "" } },
             headers: @headers

        assert_response :redirect
        assert_redirected_to sign_app_configuration_url(ri: "jp")
      end

      return_to = Base64.urlsafe_encode64(sign_app_configuration_telephones_path(ri: "jp"))
      post sign_app_verification_emails_url(ri: "jp"),
           params: { verification: { scope: "configuration_telephone", return_to: return_to } },
           headers: @headers

      assert_response :redirect
      assert_match %r{/verification/emails/.+/edit}, response.location
    end
  end

  private

  def with_verify_email_otp_stub(result)
    original_method = Sign::App::Verification::EmailsController.instance_method(:verify_email_otp!)
    Sign::App::Verification::EmailsController.define_method(:verify_email_otp!) { result }
    yield
  ensure
    Sign::App::Verification::EmailsController.define_method(:verify_email_otp!, original_method)
  end

  def with_email_nonce_stub(result)
    original_method = Sign::App::Verification::EmailsController.instance_method(:require_email_nonce!)
    Sign::App::Verification::EmailsController.define_method(:require_email_nonce!) { result }
    yield
  ensure
    Sign::App::Verification::EmailsController.define_method(:require_email_nonce!, original_method)
  end

  def cache_email_nonce!(nonce)
    rs = current_reauth_session
    Rails.cache.write("reauth_session:#{rs.id}:email_nonce", nonce, expires_in: 15.minutes)
  end

  def cache_email_otp!
    rs = current_reauth_session
    Rails.cache.write(
      "reauth_session:#{rs.id}:email_otp",
      { "secret" => "secret", "counter" => 0 },
      expires_in: 15.minutes,
    )
  end

  def email_otp_cache_key
    rs = current_reauth_session
    "reauth_session:#{rs.id}:email_otp"
  end

  def email_otp_cache_key_for_id(id)
    "reauth_session:#{id}:email_otp"
  end

  def current_reauth_session
    UserReauthSession.find_by!(user_token: @active_token).tap { |rs| @reauth_session_id = rs.id }
  end
end

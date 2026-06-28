# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Auth::App::Verification::EmailsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients

  setup do
    @previous_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @host = ENV.fetch("AUTH_SERVICE_URL")
    @user = clients(:one)
    @headers = as_user_headers(@user, host: @host)
    @token = ClientToken.find_by!(public_id: @headers["X-TEST-SESSION-PUBLIC-ID"])
    @active_token = @token
    ClientEmail.create!(
      user: @user,
      address: "verified-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_private_key: "otp_private_key",
      otp_counter: "0",
    )
  end

  teardown do
    Rails.cache = @previous_cache_store
  end

  test "new sends otp and redirects to edit" do
    return_to = auth_app_settings_emails_path(ri: "jp")

    StepUpAvailableMethods.stub(:call, [:email_otp]) do
      Email::App::OtpMailer.stub(:with, OpenStruct.new(create: OpenStruct.new(deliver_later: true))) do
        pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id)
        grant = signed_step_up_grant_for(
          actor: @user, token: @token, scope: "settings_email", return_to: return_to, surface: "app",
        )
        get auth_app_verification_url(scope: "settings_email", pt: pt, ri: "jp", step_up_ceremony_grant: grant),
            headers: @headers

        assert_response :success

        get new_auth_app_verification_email_url(ri: "jp"), headers: @headers

        assert_response :redirect

        assert_match %r{/verification/emails/.+/edit}, response.location

        follow_redirect!(headers: @headers)

        assert_response :success
        assert_select "h1", text: I18n.t("sign.app.verification.edit.title")
        assert_select "label", text: I18n.t("sign.app.verification.edit.code_label")
        assert_select "input[placeholder=?]", I18n.t("sign.app.verification.edit.code_placeholder")
        assert_select "input[type=submit][value=?]", I18n.t("sign.app.verification.edit.submit")
        assert_includes response.body, "メールアドレス"
        assert_includes response.body, I18n.t("sign.app.verification.edit.email_delivery_help")
      end
    end
  end

  test "email selection from verification page reaches otp entry page" do
    return_to = edit_auth_app_settings_email_path(
      @user.client_emails.last.public_id,
      ri: "jp",
    )

    StepUpAvailableMethods.stub(:call, [:email_otp]) do
      pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id)
      get auth_app_verification_url(scope: "settings_email", pt: pt, ri: "jp"),
          headers: @headers

      assert_response :success

      assert_match(
        %r{/verification/emails/new\?pt=.*&amp;ri=jp&amp;scope=settings_email},
        response.body,
      )

      assert_enqueued_emails 1 do
        get new_auth_app_verification_email_url(
          ri: "jp",
          scope: "settings_email",
          pt: signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id),
        ), headers: @headers
      end

      assert_response :redirect
      follow_redirect!(headers: @headers)

      assert_response :success
      assert_select "input[name='verification[code]']"
      assert_select "h1", text: I18n.t("sign.app.verification.edit.title")
      assert_select "label", text: I18n.t("sign.app.verification.edit.code_label")
      assert_select "input[placeholder=?]", I18n.t("sign.app.verification.edit.code_placeholder")
      assert_select "input[type=submit][value=?]", I18n.t("sign.app.verification.edit.submit")
      assert_includes response.body, "メールアドレス"
    end
  end

  test "new enqueues otp email while request is on readonly role" do
    @previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :solid_queue
    return_to = edit_auth_app_settings_email_path(
      @user.client_emails.last.public_id,
      ri: "jp",
    )

    StepUpAvailableMethods.stub(:call, [:email_otp]) do
      assert_difference -> { SolidQueue::Job.where(class_name: "ActionMailer::MailDeliveryJob").count }, 1 do
        ActiveRecord::Base.connected_to(role: :reading, prevent_writes: true) do
          get(
            new_auth_app_verification_email_url(
              ri: "jp",
              scope: "settings_email",
              pt: signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id),
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
    @user.client_emails.update_all(user_email_status_id: ClientEmailStatus::VERIFIED_WITH_SIGN_UP)
    return_to = auth_app_settings_emails_path(ri: "jp")

    StepUpAvailableMethods.stub(:call, [:email_otp]) do
      pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id)
      get auth_app_verification_url(scope: "settings_email", pt: pt, ri: "jp"),
          headers: @headers

      assert_response :success

      assert_enqueued_emails 1 do
        get new_auth_app_verification_email_url(ri: "jp"), headers: @headers
      end

      assert_response :redirect
      assert_match %r{/verification/emails/.+/edit}, response.location
    end
  end

  test "new keeps scope and return_to in form hidden fields" do
    return_to = auth_app_settings_emails_path(ri: "jp")

    StepUpAvailableMethods.stub(:call, [:email_otp]) do
      get new_auth_app_verification_email_url(
        ri: "jp",
        scope: "settings_email",
        pt: signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id),
      ), headers: @headers

      assert_response :redirect
      assert_match %r{/verification/emails/.+/edit}, response.location
    end
  end

  test "new restores step_up session from scope and pt query parameters" do
    return_to = auth_app_settings_emails_path(ri: "jp")

    StepUpAvailableMethods.stub(:call, [:email_otp]) do
      assert_enqueued_emails 1 do
        get new_auth_app_verification_email_url(
          ri: "jp",
          scope: "settings_email",
          pt: signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id),
        ), headers: @headers
      end

      assert_response :redirect
      assert_match %r{/verification/emails/.+/edit}, response.location
    end
  end

  test "new resends otp when otp session is already active" do
    return_to = auth_app_settings_emails_path(ri: "jp")

    pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id)
    get auth_app_verification_url(scope: "settings_email", pt: pt, ri: "jp"),
        headers: @headers

    assert_response :success
    get new_auth_app_verification_email_url(
      ri: "jp",
      scope: "settings_email",
      pt: signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id),
    ), headers: @headers

    assert_response :redirect

    StepUpAvailableMethods.stub(:call, [:email_otp]) do
      assert_enqueued_emails 1 do
        get new_auth_app_verification_email_url(
          ri: "jp",
          scope: "settings_email",
          pt: signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id),
        ), headers: @headers
      end
    end

    assert_response :redirect
    assert_match %r{/verification/emails/.+/edit}, response.location
  end

  test "edit sends otp when nonce is valid but otp session is missing" do
    return_to = auth_app_settings_emails_path(ri: "jp")

    pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id)
    get auth_app_verification_url(scope: "settings_email", pt: pt, ri: "jp"),
        headers: @headers

    assert_response :success

    nonce = SecureRandom.urlsafe_base64(16)

    StepUpAvailableMethods.stub(:call, []) do
      with_email_nonce_stub(true) do
        assert_enqueued_emails 1 do
          get edit_auth_app_verification_email_url(nonce, ri: "jp"), headers: @headers
        end
      end
    end

    assert_response :success
    assert_select "input[name='verification[code]']"
  end

  test "edit does not resend otp when otp session is already active" do
    return_to = auth_app_settings_emails_path(ri: "jp")

    pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id)
    get auth_app_verification_url(scope: "settings_email", pt: pt, ri: "jp"),
        headers: @headers

    assert_response :success

    get new_auth_app_verification_email_url(
      ri: "jp",
      scope: "settings_email",
      pt: signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id),
    ), headers: @headers

    assert_response :redirect
    nonce = response.location[%r{/verification/emails/([^/?]+)/edit}, 1]

    StepUpAvailableMethods.stub(:call, []) do
      assert_enqueued_emails 0 do
        get edit_auth_app_verification_email_url(nonce, ri: "jp"), headers: @headers
      end
    end

    assert_response :success
    assert_select "input[name='verification[code]']"
  end

  test "update verifies otp and redirects to return_to" do
    return_to = auth_app_settings_emails_path(ri: "jp")

    StepUpAvailableMethods.stub(:call, [:email_otp]) do
      Email::App::OtpMailer.stub(:with, OpenStruct.new(create: OpenStruct.new(deliver_later: true))) do
        pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id)
        grant = signed_step_up_grant_for(
          actor: @user, token: @token, scope: "settings_email", return_to: return_to, surface: "app",
        )
        get auth_app_verification_url(scope: "settings_email", pt: pt, ri: "jp", step_up_ceremony_grant: grant),
            headers: @headers

        assert_response :success

        get new_auth_app_verification_email_url(ri: "jp"), headers: @headers

        assert_response :redirect
        nonce = response.location[%r{/verification/emails/([^/?]+)/edit}, 1]

        with_email_nonce_stub(true) do
          with_verify_email_otp_stub(true) do
            patch auth_app_verification_email_url(nonce, ri: "jp"),
                  params: { verification: { code: "123456" } },
                  headers: @headers

            assert_response :success
            assert_includes response.body, "step-up-completion-form"
            assert_nil @token.reload.step_up_session
            # sign no longer writes freshness; acme commits it on completion (asserted below).

            submit_step_up_completion_if_present!(
              host: ENV.fetch("ACME_SERVICE_URL"),
              headers: as_user_headers(
                @user,
                host: ENV.fetch("ACME_SERVICE_URL"),
                session_public_id: @token.public_id,
              ),
            )

            assert_response :redirect
            assert_predicate @token.reload.last_step_up_at, :present?
            assert_equal "settings_email", @token.last_step_up_scope
          end
        end
      end
    end
  end

  test "invalid otp keeps back link from step_up session when request params are missing" do
    return_to = auth_app_settings_emails_path(ri: "jp")

    pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id)
    get auth_app_verification_url(scope: "settings_email", pt: pt, ri: "jp"),
        headers: @headers

    assert_response :success

    get new_auth_app_verification_email_url(
      ri: "jp",
      scope: "settings_email",
      pt: signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id),
    ), headers: @headers

    assert_response :redirect
    nonce = response.location[%r{/verification/emails/([^/?]+)/edit}, 1]

    patch auth_app_verification_email_url(nonce, ri: "jp"),
          params: { verification: { code: "000000" } },
          headers: @headers

    assert_response :unprocessable_content
    assert_select "a", text: I18n.t("sign.app.verification.edit.back") do |elements|
      href = elements.first["href"]

      assert_includes href, "/verification?"
      assert_includes href, "ri=jp"
      assert_includes href, "scope=settings_email"
      assert_includes href, "pt="
    end
    assert_select "input[name='verification[pt]']" do |elements|
      assert_predicate elements.first["value"], :present?
    end
  end

  test "resend sends a new otp and returns to edit page" do
    return_to = auth_app_settings_emails_path(ri: "jp")

    pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id)
    get auth_app_verification_url(scope: "settings_email", pt: pt, ri: "jp"),
        headers: @headers

    assert_response :success

    get new_auth_app_verification_email_url(
      ri: "jp",
      scope: "settings_email",
      pt: signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id),
    ), headers: @headers

    assert_response :redirect
    nonce = response.location[%r{/verification/emails/([^/?]+)/edit}, 1]

    assert_enqueued_emails 1 do
      post auth_app_verification_email_redelivery_url(
        nonce,
        ri: "jp",
        scope: "settings_email",
        pt: signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id),
      ), headers: @headers
    end

    assert_response :redirect
    assert_match %r{/verification/emails/#{Regexp.escape(nonce)}/edit\?pt=.*&ri=jp&scope=settings_email},
                 response.location
    assert_equal I18n.t("otp.resend.sent"), flash[:notice]
  end

  test "resend is rate limited" do
    return_to = auth_app_settings_emails_path(ri: "jp")

    pt = signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id)
    get auth_app_verification_url(scope: "settings_email", pt: pt, ri: "jp"),
        headers: @headers

    assert_response :success

    get new_auth_app_verification_email_url(
      ri: "jp",
      scope: "settings_email",
      pt: signed_step_up_pt_for(return_to, surface: "app", session_nonce: @token.public_id),
    ), headers: @headers

    assert_response :redirect
    nonce = response.location[%r{/verification/emails/([^/?]+)/edit}, 1]

    assert_enqueued_emails 1 do
      post auth_app_verification_email_redelivery_url(nonce, ri: "jp"), headers: @headers
    end

    assert_enqueued_emails 0 do
      post auth_app_verification_email_redelivery_url(nonce, ri: "jp"), headers: @headers
    end

    assert_response :redirect
    assert_equal I18n.t("otp.resend.too_soon"), flash[:alert]
  end

  test "settings email management requires sign step up" do
    stale_token = ClientToken.create!(user_id: @user.id, created_at: 20.minutes.ago, updated_at: 20.minutes.ago)
    stale_headers = @headers.merge("X-TEST-SESSION-PUBLIC-ID" => stale_token.public_id)
    email = @user.client_emails.where(user_email_status_id: AuthMethodGuard::VERIFIED_EMAIL_STATUSES).first

    StepUpAvailableMethods.stub(:call, [:email_otp]) do
      get edit_auth_app_settings_email_url(email.public_id, ri: "jp"), headers: stale_headers

      assert_response :redirect
      location = URI.parse(response.location)
      query = Rack::Utils.parse_query(location.query)

      assert_equal @host, location.host
      assert_equal "/verification", location.path
      assert_equal "settings_email", query["scope"]
      assert_predicate query["pt"], :present?
    end
  end

  test "create restores step_up session only when scope and return_to are present" do
    StepUpAvailableMethods.stub(:call, [:email_otp]) do
      Email::App::OtpMailer.stub(:with, OpenStruct.new(create: OpenStruct.new(deliver_later: true))) do
        post auth_app_verification_emails_url(ri: "jp"),
             params: { verification: { scope: "", pt: "" } },
             headers: @headers

        assert_response :redirect
        assert_redirected_to auth_app_settings_url(ri: "jp")
      end

      return_to = auth_app_settings_telephones_path(ri: "jp")
      post auth_app_verification_emails_url(ri: "jp"),
           params: { verification: { scope: "settings_telephone",
                                     pt: signed_step_up_pt_for(
                                       return_to, surface: "app",
                                                  session_nonce: @token.public_id,
                                     ), } },
           headers: @headers

      assert_response :redirect
      assert_match %r{/verification/emails/.+/edit}, response.location
    end
  end

  private

  def with_verify_email_otp_stub(result)
    original_method = Auth::App::Verification::EmailsController.instance_method(:verify_email_otp!)
    Auth::App::Verification::EmailsController.define_method(:verify_email_otp!) { result }
    yield
  ensure
    Auth::App::Verification::EmailsController.define_method(:verify_email_otp!, original_method)
  end

  def with_email_nonce_stub(result)
    original_method = Auth::App::Verification::EmailsController.instance_method(:require_email_nonce!)
    Auth::App::Verification::EmailsController.define_method(:require_email_nonce!) { result }
    yield
  ensure
    Auth::App::Verification::EmailsController.define_method(:require_email_nonce!, original_method)
  end

  def current_step_up_session
    ClientStepUpSession.find_by!(user_token: @active_token).tap { |rs| @step_up_session_id = rs.id }
  end
end

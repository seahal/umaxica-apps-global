# typed: false
# frozen_string_literal: true

require "test_helper"

# `sign_up_suspended_{surface}` is an operational kill switch: it closes new
# registration on one trust boundary without touching sign-in and without
# affecting the other two surfaces.
class SignUpSuspensionRequestTest < ActionDispatch::IntegrationTest
  SURFACES = {
    app: { host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"), feature: :sign_up_suspended_app },
    com: { host: ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost"), feature: :sign_up_suspended_com },
    org: { host: ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost"), feature: :sign_up_suspended_org },
  }.freeze

  teardown do
    SURFACES.each_value { |surface| Flipper.disable(surface.fetch(:feature)) }
  end

  SURFACES.each do |surface, config|
    test "#{surface} sign-up entry is open while the switch is off" do
      host! config.fetch(:host)

      get sign_up_path_for(surface)

      assert_response :success
    end

    test "#{surface} sign-up entry answers 503 while suspended" do
      Flipper.enable(config.fetch(:feature))
      host! config.fetch(:host)

      get sign_up_path_for(surface)

      assert_response :service_unavailable
      assert_select "[data-test-id=?]", "sign-up-suspended"
    end

    test "#{surface} sign-in entry is unaffected by the sign-up switch" do
      Flipper.enable(config.fetch(:feature))
      host! config.fetch(:host)

      get sign_in_path_for(surface)

      assert_response :success
    end
  end

  test "suspending one surface leaves the others open" do
    Flipper.enable(:sign_up_suspended_app)

    host! SURFACES.fetch(:com).fetch(:host)
    get auth_com_sign_up_path

    assert_response :success

    host! SURFACES.fetch(:org).fetch(:host)
    get auth_org_sign_up_path

    assert_response :success
  end

  # The identifier entry is where a registration actually starts, so a suspended
  # surface must reject it too -- a landing page that merely hides its links
  # would still accept a direct POST.
  test "app email registration entry answers 503 while suspended" do
    Flipper.enable(:sign_up_suspended_app)
    host! SURFACES.fetch(:app).fetch(:host)

    # `ri` is supplied so the region redirect that precedes the guard does not
    # answer first; the assertion is about the guard, not about that redirect.
    get new_auth_app_sign_up_email_path(ri: "jp")

    assert_response :service_unavailable
  end

  # The social ceremony entry shares its concern with sign-in, so only the
  # sign-up branch may be closed, and it must be closed before any ceremony
  # state is written.
  test "app social registration entry answers 503 and issues no sign-up flow while suspended" do
    Flipper.enable(:sign_up_suspended_app)
    host! SURFACES.fetch(:app).fetch(:host)

    assert_no_difference -> { ClientSignUpFlow.count } do
      post auth_app_social_google_registration_path
    end

    assert_response :service_unavailable
  end

  test "app social sign-in entry still starts its ceremony while sign-up is suspended" do
    Flipper.enable(:sign_up_suspended_app)
    host! SURFACES.fetch(:app).fetch(:host)

    post auth_app_social_google_session_path

    assert_response :temporary_redirect
  end

  private

  def sign_up_path_for(surface)
    public_send(:"auth_#{surface}_sign_up_path")
  end

  def sign_in_path_for(surface)
    public_send(:"auth_#{surface}_sign_in_path")
  end
end

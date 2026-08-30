# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::App::Identity::TelephonesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = configured_host(:base_service)
    ensure_client_reference_records!
    @client = Client.create!(status_id: ClientStatus::NOTHING)
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "index lists the telephones the client already holds" do
    verified = create_telephone(status_id: ClientTelephoneStatus::VERIFIED)

    get base_app_identity_telephones_url(ri: "jp", host: @host), headers: step_up_headers

    assert_response :success
    assert_includes response.body, verified.public_id
  end

  test "index renders for a client with no telephone at all" do
    get base_app_identity_telephones_url(ri: "jp", host: @host), headers: step_up_headers

    assert_response :success
  end

  test "new renders the number form" do
    get new_base_app_identity_telephone_url(ri: "jp", host: @host), headers: step_up_headers

    assert_response :success
  end

  test "edit renders the delete form for a telephone the client owns" do
    telephone = create_telephone(status_id: ClientTelephoneStatus::VERIFIED)

    get edit_base_app_identity_telephone_url(telephone.public_id, ri: "jp", host: @host),
        headers: step_up_headers

    assert_response :success
  end

  test "edit does not find a telephone owned by another client" do
    other = Client.create!(status_id: ClientStatus::NOTHING)
    foreign = create_telephone(client: other, status_id: ClientTelephoneStatus::VERIFIED)

    get edit_base_app_identity_telephone_url(foreign.public_id, ri: "jp", host: @host),
        headers: step_up_headers

    assert_response :not_found
  end

  test "create starts the verification flow and hands off to the registration step" do
    post base_app_identity_telephones_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: unique_number } },
         headers: step_up_headers

    assert_response :see_other
    assert_equal 1, @client.client_telephones.reload.count
  end

  test "create re-renders the number form when the number cannot be normalized" do
    post base_app_identity_telephones_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: "not-a-telephone-number" } },
         headers: step_up_headers

    assert_response :unprocessable_content
    assert_equal 0, @client.client_telephones.reload.count
  end

  test "destroy removes the telephone when another sign-in method remains" do
    create_telephone(status_id: ClientTelephoneStatus::VERIFIED)
    removable = create_telephone(status_id: ClientTelephoneStatus::VERIFIED)

    delete base_app_identity_telephone_url(removable.public_id, ri: "jp", host: @host),
           headers: step_up_headers

    assert_response :see_other
    assert_redirected_to base_app_identity_telephones_path(ri: "jp")
    assert_nil ClientTelephone.find_by(id: removable.id)
  end

  test "destroy does not find a telephone owned by another client" do
    other = Client.create!(status_id: ClientStatus::NOTHING)
    foreign = create_telephone(client: other, status_id: ClientTelephoneStatus::VERIFIED)

    delete base_app_identity_telephone_url(foreign.public_id, ri: "jp", host: @host),
           headers: step_up_headers

    assert_response :not_found
    assert_not_nil ClientTelephone.find_by(id: foreign.id)
  end

  private

  def unique_number
    "+8190#{format("%08d", SecureRandom.random_number(100_000_000))}"
  end

  def create_telephone(client: @client, status_id:)
    client.client_telephones.create!(
      number: unique_number,
      user_telephone_status_id: status_id,
    )
  end

  # Authentication and step-up material go into the integration cookie jar rather than a literal
  # Cookie header, so the Rails session cookie set by one request survives into the next one.
  def step_up_headers
    return @step_up_headers if @step_up_headers

    headers = as_user_headers(@client, host: @host)
    token = authentication_harness_latest_token(@client)
    mark_token_step_up_satisfied_for_test(token, scope: "settings_telephone")
    _verification, raw_token = ClientVerification.issue_for_token!(token: token)
    access_token = headers["Cookie"].to_s[/#{Regexp.escape(AuthenticationBase::ACCESS_COOKIE_KEY)}=([^;]+)/, 1]
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    cookies[ClientVerification.cookie_name] = raw_token

    @step_up_headers = headers.except("Cookie", "HTTP_COOKIE")
  end

  def ensure_client_reference_records!
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    [
      ClientTelephoneStatus::UNVERIFIED,
      ClientTelephoneStatus::VERIFIED,
      ClientTelephoneStatus::NOTHING,
    ].each { |id| ClientTelephoneStatus.find_or_create_by!(id: id) }
  end

  # DAMP local helper copy for former shared test support.
  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def mark_token_step_up_satisfied_for_test(token, scope: nil, at: Time.current)
    return unless token.respond_to?(:update_columns)

    attrs = {
      last_step_up_at: at,
      last_step_up_scope: scope.presence || "verification",
      last_step_up_aal: ("aal2" if token.respond_to?(:last_step_up_aal)),
      last_step_up_method: ("passkey" if token.respond_to?(:last_step_up_method)),
      last_step_up_session_public_id: (token.public_id if token.respond_to?(:last_step_up_session_public_id)),
      last_step_up_purpose: ("step_up" if token.respond_to?(:last_step_up_purpose)),
      last_step_up_audience: ("step_up:app" if token.respond_to?(:last_step_up_audience)),
      updated_at: Time.current,
    }.compact
    token.update_columns(attrs)
  end
end

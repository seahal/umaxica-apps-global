# typed: false
# frozen_string_literal: true

require "test_helper"

class AcmeStepUpIntentAuthorityTest < ActionDispatch::IntegrationTest
  fixtures :clients, :operators, :client_statuses, :client_token_kinds, :client_token_statuses,
           :operator_tokens, :operator_passkeys

  test "app acme verification intent creates transaction and redirects to sign ceremony with grant" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    user = clients(:one)
    ClientEmail.create!(
      user: user,
      address: "step-up-intent-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_private_key: "otp_private_key",
      otp_counter: "0",
    )
    token = create_client_token!(user)
    pt = signed_step_up_pt_for(acme_app_settings_emails_path(ri: "jp"), surface: "app", session_nonce: token.public_id)

    assert_difference -> { ClientStepUpCeremonyTransaction.count }, 1 do
      get acme_app_verification_url(scope: "settings_email", pt: pt, ri: "jp", host: host),
          headers: app_session_headers(host, token, user)
    end

    assert_response :see_other
    query = redirect_query

    assert_equal "settings_email", query["scope"]
    assert_equal pt, query["pt"]
    assert_predicate query["step_up_ceremony_grant"], :present?
    assert_predicate query["step_up_completion_csrf"], :present?

    grant = decode_grant(query["step_up_ceremony_grant"], surface: "app")
    transaction = ClientStepUpCeremonyTransaction.find_by!(transaction_id: grant["transaction_id"])

    assert_equal user.public_id, grant["actor_ref"]
    assert_equal token.public_id, grant["session_ref"]
    assert_equal "settings_email", transaction.required_scope
    assert_equal "aal2", transaction.required_aal
    assert_nil token.reload.last_step_up_at
  end

  test "app acme completion consumes result and commits freshness" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    user = clients(:one)
    token = create_client_token!(user)
    return_to = acme_app_settings_emails_path(ri: "jp")
    issuance = issue_step_up_grant!(
      surface: "app",
      actor_ref: user.public_id,
      session_ref: token.public_id,
      scope: "settings_email",
      methods: ["passkey"],
      return_to: return_to,
    )
    result = issue_step_up_result!(
      surface: "app",
      actor_ref: user.public_id,
      session_ref: token.public_id,
      transaction: issuance.transaction,
      method: "passkey",
    )

    post completion_acme_app_verification_url(ri: "jp", host: host),
         params: { step_up_ceremony_result: result },
         headers: app_session_headers(host, token, user)

    assert_response :see_other
    assert_equal return_to, URI.parse(response.location).request_uri
    token.reload

    assert_not_nil token.last_step_up_at
    assert_equal "settings_email", token.last_step_up_scope
    assert_equal "passkey", token.last_step_up_method
    assert_equal "aal2", token.last_step_up_aal
  end

  test "app acme completion route is post only" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("https://#{host}/verification/completion", method: :get)
    end

    recognized = Rails.application.routes.recognize_path("https://#{host}/verification/completion", method: :post)

    assert_equal "acme/app/verifications", recognized[:controller]
    assert_equal "completion", recognized[:action]
  end

  test "app acme completion rejects missing csrf token when forgery protection is enabled" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    user = clients(:one)
    token = create_client_token!(user)
    issuance = issue_step_up_grant!(
      surface: "app",
      actor_ref: user.public_id,
      session_ref: token.public_id,
      scope: "settings_email",
      methods: ["passkey"],
      return_to: acme_app_settings_emails_path(ri: "jp"),
    )
    result = issue_step_up_result!(
      surface: "app",
      actor_ref: user.public_id,
      session_ref: token.public_id,
      transaction: issuance.transaction,
      method: "passkey",
    )

    with_forgery_protection do
      post completion_acme_app_verification_url(ri: "jp", host: host),
           params: { step_up_ceremony_result: result },
           headers: app_session_headers(host, token, user)
    end

    assert_response :unprocessable_content
    assert_nil token.reload.last_step_up_at
    assert_not_predicate issuance.transaction.reload, :consumed?
  end

  test "app acme intent supplies csrf token for sign completion post" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    user = clients(:one)
    ClientEmail.create!(
      user: user,
      address: "step-up-completion-csrf-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_private_key: "otp_private_key",
      otp_counter: "0",
    )
    token = create_client_token!(user)
    pt = signed_step_up_pt_for(acme_app_settings_emails_path(ri: "jp"), surface: "app", session_nonce: token.public_id)

    get acme_app_verification_url(scope: "settings_email", pt: pt, ri: "jp", host: host),
        headers: app_session_headers(host, token, user)

    assert_response :see_other
    query = redirect_query

    assert_predicate query["step_up_completion_csrf"], :present?
    assert_predicate query["step_up_ceremony_grant"], :present?
    assert_not_equal query["step_up_completion_csrf"], query["step_up_ceremony_grant"]
  end

  test "app acme completion ignores unsafe transaction return target" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    user = clients(:one)
    token = create_client_token!(user)
    issuance = issue_step_up_grant!(
      surface: "app",
      actor_ref: user.public_id,
      session_ref: token.public_id,
      scope: "settings_email",
      methods: ["passkey"],
      return_to: "https://evil.example/steal",
    )
    result = issue_step_up_result!(
      surface: "app",
      actor_ref: user.public_id,
      session_ref: token.public_id,
      transaction: issuance.transaction,
      method: "passkey",
    )

    post completion_acme_app_verification_url(ri: "jp", host: host),
         params: { step_up_ceremony_result: result },
         headers: app_session_headers(host, token, user)

    assert_response :see_other
    uri = URI.parse(response.location)

    assert_not_equal "evil.example", uri.host
    assert_includes [nil, host], uri.host
    assert_equal acme_app_dashboard_path(ri: "jp"), uri.request_uri
    assert_equal "settings_email", token.reload.last_step_up_scope
  end

  test "sign completion transport posts result body only to fixed acme endpoint" do
    source = Rails.root.join("app/views/sign/shared/step_up_completion.html.erb").read

    assert_includes source, "form_with url: completion_url, method: :post"
    assert_includes source, "authenticity_token: false"
    assert_includes source, "hidden_field_tag :authenticity_token, csrf_token"
    assert_includes source, "hidden_field_tag :step_up_ceremony_result, result_token"
    assert_no_match(/step_up_ceremony_result.*completion_url/, source)
    assert_no_match(/return_to/, source)
  end

  test "acme completion controllers do not skip forgery protection" do
    [
      "app/controllers/acme/app/verifications_controller.rb",
      "app/controllers/acme/com/verifications_controller.rb",
      "app/controllers/acme/org/verifications_controller.rb",
      "app/controllers/concerns/acme_step_up_completion.rb",
    ].each do |path|
      assert_not_includes Rails.root.join(path).read, "skip_forgery_protection"
    end
  end

  test "app acme completion rejects replay without refreshing token" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    user = clients(:one)
    token = create_client_token!(user)
    issuance = issue_step_up_grant!(
      surface: "app",
      actor_ref: user.public_id,
      session_ref: token.public_id,
      scope: "settings_email",
      methods: ["passkey"],
      return_to: acme_app_settings_emails_path(ri: "jp"),
    )
    result = issue_step_up_result!(
      surface: "app",
      actor_ref: user.public_id,
      session_ref: token.public_id,
      transaction: issuance.transaction,
      method: "passkey",
    )

    post completion_acme_app_verification_url(ri: "jp", host: host),
         params: { step_up_ceremony_result: result },
         headers: app_session_headers(host, token, user)
    first_step_up_at = token.reload.last_step_up_at

    post completion_acme_app_verification_url(ri: "jp", host: host),
         params: { step_up_ceremony_result: result },
         headers: app_session_headers(host, token, user)

    assert_response :bad_request
    assert_equal first_step_up_at, token.reload.last_step_up_at
  end

  test "app acme completion rejects wrong session result" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    user = clients(:one)
    token = create_client_token!(user)
    other_token = create_client_token!(user)
    issuance = issue_step_up_grant!(
      surface: "app",
      actor_ref: user.public_id,
      session_ref: other_token.public_id,
      scope: "settings_email",
      methods: ["passkey"],
      return_to: acme_app_settings_emails_path(ri: "jp"),
    )
    result = issue_step_up_result!(
      surface: "app",
      actor_ref: user.public_id,
      session_ref: other_token.public_id,
      transaction: issuance.transaction,
      method: "passkey",
    )

    post completion_acme_app_verification_url(ri: "jp", host: host),
         params: { step_up_ceremony_result: result },
         headers: app_session_headers(host, token, user)

    assert_response :bad_request
    assert_nil token.reload.last_step_up_at
    assert_not_predicate issuance.transaction.reload, :consumed?
  end

  test "sign ceremony accepts acme issued grant without creating a compatibility transaction" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    sign_host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    user = clients(:one)
    ClientEmail.create!(
      user: user,
      address: "sign-accepts-acme-grant-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_private_key: "otp_private_key",
      otp_counter: "0",
    )
    token = create_client_token!(user)
    pt = signed_step_up_pt_for(acme_app_settings_emails_path(ri: "jp"), surface: "app", session_nonce: token.public_id)

    get acme_app_verification_url(scope: "settings_email", pt: pt, ri: "jp", host: host),
        headers: app_session_headers(host, token, user)
    sign_location = response.location

    assert_no_difference -> { ClientStepUpCeremonyTransaction.count } do
      get sign_location, headers: app_session_headers(sign_host, token, user)
    end

    assert_response :success
  end

  test "app acme verification intent rejects arbitrary scope" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    user = clients(:one)
    token = create_client_token!(user)
    pt = signed_step_up_pt_for(acme_app_settings_emails_path(ri: "jp"), surface: "app", session_nonce: token.public_id)

    assert_no_difference -> { ClientStepUpCeremonyTransaction.count } do
      get acme_app_verification_url(scope: "admin", pt: pt, ri: "jp", host: host),
          headers: app_session_headers(host, token, user)
    end

    assert_response :bad_request
  end

  test "app acme verification intent rejects mismatched return target" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    user = clients(:one)
    token = create_client_token!(user)
    pt = signed_step_up_pt_for(acme_app_settings_emails_path(ri: "jp"), surface: "app", session_nonce: token.public_id)

    assert_no_difference -> { ClientStepUpCeremonyTransaction.count } do
      get acme_app_verification_url(scope: "settings_telephone", pt: pt, ri: "jp", host: host),
          headers: app_session_headers(host, token, user)
    end

    assert_response :bad_request
  end

  test "acme protected app action redirects to acme verification intent instead of direct sign verification" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    user = clients(:one)
    ClientEmail.create!(
      user: user,
      address: "protected-intent-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_private_key: "otp_private_key",
      otp_counter: "0",
    )
    token = create_client_token!(user)

    get acme_app_settings_emails_url(ri: "jp", host: host), headers: app_session_headers(host, token, user)

    assert_response :found
    uri = URI.parse(response.location)

    assert_equal "/verification", uri.path
    assert_equal host, uri.host
    assert_equal "settings_email", Rack::Utils.parse_query(uri.query)["scope"]
  end

  test "com acme verification intent creates visitor transaction" do
    host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    visitor = create_verified_visitor_with_email(email_address: "visitor-step-up-#{SecureRandom.hex(4)}@example.com")
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    pt = signed_step_up_pt_for(acme_com_settings_emails_path(ri: "jp"), surface: "com", session_nonce: token.public_id)

    assert_difference -> { VisitorStepUpCeremonyTransaction.count }, 1 do
      get acme_com_verification_url(scope: "settings_email", pt: pt, ri: "jp", host: host),
          headers: com_session_headers(host, token, visitor)
    end

    assert_response :see_other
    grant = decode_grant(redirect_query["step_up_ceremony_grant"], surface: "com")

    assert_equal visitor.public_id, grant["actor_ref"]
    assert_equal token.public_id, grant["session_ref"]
  end

  test "com acme completion consumes result and commits freshness" do
    host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    visitor = create_verified_visitor_with_email(email_address: "visitor-completion-#{SecureRandom.hex(4)}@example.com")
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    issuance = issue_step_up_grant!(
      surface: "com",
      actor_ref: visitor.public_id,
      session_ref: token.public_id,
      scope: "settings_email",
      methods: ["passkey"],
      return_to: acme_com_settings_emails_path(ri: "jp"),
    )
    result = issue_step_up_result!(
      surface: "com",
      actor_ref: visitor.public_id,
      session_ref: token.public_id,
      transaction: issuance.transaction,
      method: "passkey",
    )

    post completion_acme_com_verification_url(ri: "jp", host: host),
         params: { step_up_ceremony_result: result },
         headers: com_session_headers(host, token, visitor)

    assert_response :see_other
    assert_equal "settings_email", token.reload.last_step_up_scope
  end

  test "org acme verification intent creates operator transaction" do
    host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    operator = operators(:one)
    token = operator_tokens(:one)
    pt = signed_step_up_pt_for(acme_org_settings_emails_path(ri: "jp"), surface: "org", session_nonce: token.public_id)

    assert_difference -> { OperatorStepUpCeremonyTransaction.count }, 1 do
      get acme_org_verification_url(scope: "settings_email", pt: pt, ri: "jp", host: host),
          headers: org_session_headers(host, token, operator)
    end

    assert_response :see_other
    grant = decode_grant(redirect_query["step_up_ceremony_grant"], surface: "org")

    assert_equal operator.public_id, grant["actor_ref"]
    assert_equal token.public_id, grant["session_ref"]
  end

  test "org acme completion consumes result and commits freshness" do
    host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    operator = operators(:one)
    token = operator_tokens(:one)
    issuance = issue_step_up_grant!(
      surface: "org",
      actor_ref: operator.public_id,
      session_ref: token.public_id,
      scope: "settings_email",
      methods: ["passkey"],
      return_to: acme_org_settings_emails_path(ri: "jp"),
    )
    result = issue_step_up_result!(
      surface: "org",
      actor_ref: operator.public_id,
      session_ref: token.public_id,
      transaction: issuance.transaction,
      method: "passkey",
    )

    post completion_acme_org_verification_url(ri: "jp", host: host),
         params: { step_up_ceremony_result: result },
         headers: org_session_headers(host, token, operator)

    assert_response :see_other
    assert_equal "settings_email", token.reload.last_step_up_scope
  end

  private

  def create_client_token!(user)
    ClientToken.create!(
      user: user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
  end

  def app_session_headers(host, token, user)
    { "Host" => host, "X-TEST-CURRENT-USER" => user.id.to_s, "X-TEST-SESSION-PUBLIC-ID" => token.public_id }
  end

  def com_session_headers(host, token, visitor)
    { "Host" => host, "X-TEST-CURRENT-RESOURCE" => visitor.id.to_s, "X-TEST-SESSION-PUBLIC-ID" => token.public_id }
  end

  def org_session_headers(host, token, operator)
    { "Host" => host, "X-TEST-CURRENT-STAFF" => operator.id.to_s, "X-TEST-SESSION-PUBLIC-ID" => token.public_id }
  end

  def with_forgery_protection
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  def redirect_query
    Rack::Utils.parse_query(URI.parse(response.location).query)
  end

  def decode_grant(token, surface:)
    IdentityStepUpCeremonyGrant.decode(
      token,
      issuer_id: IdentityStepUpCeremonyContract.acme_issuer_id(surface),
    )
  end

  def issue_step_up_grant!(surface:, actor_ref:, session_ref:, scope:, methods:, return_to:)
    IdentityStepUpCeremonyGrantIssuer.issue!(
      surface: surface,
      actor_ref: actor_ref,
      session_ref: session_ref,
      required_scope: scope,
      required_aal: "aal2",
      allowed_methods: methods,
      return_to: return_to,
      expires_at: 10.minutes.from_now,
    )
  end

  def issue_step_up_result!(surface:, actor_ref:, session_ref:, transaction:, method:)
    IdentityStepUpCeremonyResultIssuer.issue!(
      surface: surface,
      actor_ref: actor_ref,
      session_ref: session_ref,
      transaction_id: transaction.transaction_id,
      grant_jti: transaction.grant_jti,
      scope: transaction.required_scope,
      aal: "aal2",
      method: method,
      challenge_id: "test-challenge-#{SecureRandom.hex(4)}",
      expires_at: transaction.expires_at,
    )
  end
end

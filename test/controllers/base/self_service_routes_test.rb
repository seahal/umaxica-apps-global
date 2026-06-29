# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"
require "helpers/auth_helpers"

class BaseSelfServiceRoutesTest < ActionDispatch::IntegrationTest
  include AuthHelpers

  fixtures :clients, :client_statuses, :operators

  setup do
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    @app_host = hosts.base_service.host
    @org_host = hosts.base_staff.host
    @com_host = hosts.base_corporate.host
    @app_authority_host = hosts.acme_service.host
    @org_authority_host = hosts.acme_staff.host
    @com_authority_host = hosts.acme_corporate.host
  end

  # The app surface no longer exposes singular current self-service pages (/account, /avatar,
  # /organization). Entity CRUD lives at the plural resources and is covered by the dedicated
  # base/app controller tests; current-context display/switching lives at /switcher. Only the
  # identity self-service page remains here. Org/com singular self-service pages are unchanged.
  test "app self service identity page requires authentication" do
    assert_requires_authentication(base_app_identity_url(ri: "jp", host: @app_host), host: @app_host)
  end

  test "org self service pages require authentication" do
    assert_requires_authentication(base_org_avatar_url(ri: "jp", host: @org_host), host: @org_host)
    assert_requires_authentication(base_org_identity_url(ri: "jp", host: @org_host), host: @org_host)
    assert_requires_authentication(base_org_current_organization_url(ri: "jp", host: @org_host), host: @org_host)
    assert_requires_authentication(base_org_account_url(ri: "jp", host: @org_host), host: @org_host)
  end

  test "org self service pages render for signed in operator" do
    operator = operators(:one)
    token = OperatorToken.create!(staff: operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    select_token!(surface: :org, principal: operator, token: token)
    headers = as_staff_headers(operator, host: @org_host, session_public_id: token.public_id)
    set_access_cookie(
      jwt_access_token_for(
        operator, host: @org_host, session_public_id: token.public_id,
                  resource_type: "operator",
      ),
    )

    assert_self_service_page(base_org_identity_url(ri: "jp", host: @org_host), headers: headers, title: "Identity")
    assert_self_service_page(base_org_avatar_url(ri: "jp", host: @org_host), headers: headers, title: "Avatar")
  end

  test "com self service pages require authentication" do
    assert_requires_authentication(base_com_identity_url(ri: "jp", host: @com_host), host: @com_host)
    assert_requires_authentication(base_com_account_url(ri: "jp", host: @com_host), host: @com_host)
  end

  test "com self service pages render for signed in visitor" do
    visitor = create_verified_visitor_with_email(email_address: "base-self-service-#{SecureRandom.hex(4)}@example.com")
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    select_token!(surface: :com, principal: visitor, token: token)
    headers = as_visitor_headers(visitor, host: @com_host, session_public_id: token.public_id)
    set_access_cookie(
      jwt_access_token_for(
        visitor, host: @com_host, session_public_id: token.public_id,
                 resource_type: "visitor",
      ),
    )

    assert_self_service_page(base_com_identity_url(ri: "jp", host: @com_host), headers: headers, title: "Identity")
  end

  test "com does not expose avatar or organization self service routes" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("https://#{@com_host}/avatar", method: :get)
    end
  end

  private

  def select_token!(surface:, principal:, token:)
    BaseSelectorBootstrapAuthority.call(surface: surface, principal: principal)
    BaseSelectorAuthority.prepare(surface: surface, principal: principal, session: token)
  end

  def assert_requires_authentication(url, host:)
    get(url, headers: host_headers(host))

    assert_response :redirect
    authority_host =
      case host
      when @app_host then @app_authority_host
      when @org_host then @org_authority_host
      when @com_host then @com_authority_host
      else host
      end

    assert_oidc_authorize_redirect(response.location, host: authority_host)
  end

  def assert_self_service_page(url, headers:, title:)
    get(url, headers: headers)

    assert_response :success
    assert_select "h1", title
    assert_includes response.body, "Signed in"
    assert_no_match(/id\.umaxica/, response.body)
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class BaseSettingsAuthoritySlice1GTest < ActionDispatch::IntegrationTest
  fixtures :clients, :operators, :client_statuses, :client_token_kinds, :client_token_statuses,
           :client_chronicle_events, :client_chronicle_levels

  test "base app settings shell route is removed" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")}/settings",
        method: :get,
      )
    end
  end

  test "base app activities list only current user entries" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    host! host
    user = clients(:one)
    other_user = clients(:two)
    ChronicleRecord.connected_to(role: :writing) { ClientChronicle.delete_all }
    create_user_audit(user: user, tag: "my-login-event")
    create_user_audit(user: other_user, tag: "other-login-event")

    token = create_user_token!(user)
    select_token!(surface: :app, principal: user, token: token)

    get sign_app_settings_activities_url(ri: "jp", host: host), headers: app_session_headers(host, token, user)

    assert_response :success
    assert_no_match(/id\.umaxica/, response.body)
    assert_includes response.body, "my-login-event"
    assert_not_includes response.body, "other-login-event"
  end

  test "base com and org settings shell routes are removed" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost")}/settings",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")}/settings",
        method: :get,
      )
    end
  end

  private

  def create_user_token!(user)
    token = ClientToken.new(
      user: user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    token.send(:skip_session_limit_check=, true)
    token.save!
    token
  end

  def select_token!(surface:, principal:, token:)
    BaseSelectorBootstrapAuthority.call(surface: surface, principal: principal)
    BaseSelectorAuthority.prepare(surface: surface, principal: principal, session: token)
  end

  def app_session_headers(host, token, user)
    {
      "Host" => host,
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end

  def create_user_audit(user:, tag:)
    ChronicleRecord.connected_to(role: :writing) do
      ClientChronicle.create!(
        subject_id: user.id,
        subject_type: "Client",
        event_id: ClientChronicleEvent::LOGGED_IN,
        context: { tag: tag },
        occurred_at: Time.current,
      )
    end
  end
end

# DAMP local route helper aliases for former shared test support.
class BaseSettingsAuthoritySlice1GTest
  SURFACE_ROUTE_PREFIX_MAP = {
    "sign_app_" => "auth_app_",
    "sign_org_" => "auth_org_",
    "sign_com_" => "auth_com_",
    "acme_app_" => "base_app_",
    "acme_org_" => "base_org_",
    "acme_com_" => "base_com_",
  }.freeze unless const_defined?(:SURFACE_ROUTE_PREFIX_MAP, false)

  private

  def method_missing(name, ...)
    aliased_name = aliased_surface_route_helper_name(name)
    return public_send(aliased_name, ...) if aliased_name && respond_to?(aliased_name, true)

    super
  end

  def respond_to_missing?(name, include_private = false)
    aliased_name = aliased_surface_route_helper_name(name)
    (aliased_name && respond_to?(aliased_name, include_private)) || super
  end

  def aliased_surface_route_helper_name(name)
    helper_name = name.to_s
    self.class::SURFACE_ROUTE_PREFIX_MAP.each do |source_prefix, target_prefix|
      return helper_name.sub(source_prefix, target_prefix).to_sym if helper_name.start_with?(source_prefix)
    end
    nil
  end
end

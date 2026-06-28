# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Com::Sign::In::SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("AUTH_CORPORATE_URL", "auth.com.localhost")
    @host = ENV.fetch("AUTH_CORPORATE_URL", "auth.com.localhost")
    @visitor = create_verified_visitor_with_email(email_address: "sessions-#{SecureRandom.hex(4)}@example.com")
    @visitor.visitor_telephones.create!(
      number: "+10000000991",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    @token = create_restricted_session(@visitor)
    satisfy_visitor_verification(@token)
  end

  test "show redirects to login when not authenticated" do
    get auth_com_sign_in_session_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :redirect
    assert_redirected_to %r{/sign/in\?ri=jp}
  end

  test "protected settings sessions requires authentication" do
    with_env(
      "SIGN_CORPORATE_URL" => "auth.com.localhost",
      "ACME_CORPORATE_URL" => "log.umaxica.com",
    ) do
      Rails.application.reload_routes!

      get(
        "https://log.umaxica.com/settings/sessions?ri=jp",
        headers: { "Host" => "log.umaxica.com" },
      )

      assert_response :redirect
      assert_not_includes response.location, "token="
      assert_not_includes response.location, "session_id="
    end
  ensure
    Rails.application.reload_routes!
  end

  test "show with restricted session displays sessions" do
    create_active_session(@visitor)
    headers = request_headers(@token)

    get auth_com_sign_in_session_url(ri: "jp"), headers: headers

    assert_response :success
    assert_not response.redirect?
    assert_select "form[data-turbo=false][action=?]", auth_com_sign_in_session_path(ri: "jp")
    assert_select "input[type=radio][name=ref]"
    assert_select "form[data-turbo=false] button", text: /キャンセルしてログアウト/
  end

  test "update without selections flashes alert and re-renders show" do
    headers = request_headers(@token)

    patch auth_com_sign_in_session_url(ri: "jp"), params: { revoke_refs: [] }, headers: headers

    assert_response :unprocessable_content
  end

  test "update with ref param revokes specific session" do
    active_token = create_active_session(@visitor)
    headers = request_headers(@token)

    patch auth_com_sign_in_session_url(ri: "jp"), params: { ref: active_token.signed_ref }, headers: headers

    assert_response :redirect
    # Redirect to settings because restricted session is promoted after revoking the only active session
    assert_match %r{/settings\?ri=jp}, response.location
    assert_not_nil active_token.reload.discarded_at
    assert_equal VisitorTokenStatus::ACTIVE, @token.reload.visitor_token_status_id
  end

  test "update with ref belonging to another visitor does not revoke" do
    other_visitor = create_verified_visitor_with_email(email_address: "other-ses-#{SecureRandom.hex(4)}@example.com")
    other_token = create_active_session(other_visitor)
    headers = request_headers(@token)

    patch auth_com_sign_in_session_url(ri: "jp"), params: { ref: other_token.signed_ref }, headers: headers

    assert_response :redirect
    assert_predicate other_token.reload, :currently_usable?
  end

  test "destroy without ref logs out and redirects to login" do
    headers = request_headers(@token)

    delete auth_com_sign_in_session_url(ri: "jp"), headers: headers

    assert_response :see_other
    assert_match %r{/sign/in\?ri=jp}, response.location
  end

  test "delete session route logs out and redirects to login" do
    headers = request_headers(@token)

    delete auth_com_sign_in_session_url(ri: "jp"), headers: headers

    assert_response :see_other
    assert_match %r{/sign/in\?ri=jp}, response.location
    assert_not_predicate @token.reload, :currently_usable?
    assert_equal VisitorTokenStatus::REVOKED, @token.visitor_token_status_id
  end

  test "destroy with ref belonging to another visitor does not revoke" do
    other_visitor = create_verified_visitor_with_email(email_address: "other-des-#{SecureRandom.hex(4)}@example.com")
    other_token = create_active_session(other_visitor)
    headers = request_headers(@token)

    delete auth_com_sign_in_session_url(ri: "jp"), params: { ref: other_token.signed_ref }, headers: headers

    assert_response :success
    assert_predicate other_token.reload, :currently_usable?
  end

  test "direct controller session management branches" do
    controller = Auth::Com::Sign::In::SessionsController.new
    controller.request = ActionDispatch::TestRequest.create(
      "REQUEST_METHOD" => "GET",
      "HTTP_HOST" => ENV.fetch("COM_SERVICE_URL", "com.app.localhost"),
    )
    controller.response = ActionDispatch::TestResponse.new
    session_hash = {}
    flash_hash = Class.new(Hash) {
      define_method(:now) do
        self
      end
    }.new

    redirects = []
    renders = []
    heads = []
    jumps = []

    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:flash) { flash_hash }
    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp") }
    controller.define_singleton_method(:logged_in?) { @logged_in_for_test }
    controller.define_singleton_method(:current_session_restricted?) { @restricted_for_test }
    controller.define_singleton_method(:session_limit_gate_valid?) { @gate_for_test }
    controller.define_singleton_method(:current_resource) { @resource_for_test }
    controller.define_singleton_method(:current_session) { @session_for_test }
    controller.define_singleton_method(:current_session_public_id) { @session_for_test&.public_id }
    controller.define_singleton_method(:consume_session_limit_gate!) { @gate_consumed_for_test = true }
    controller.define_singleton_method(:log_out) { @logged_out_for_test = true }
    controller.define_singleton_method(:retrieve_pt) { @redirect_parameter_for_test }
    controller.define_singleton_method(:session_limit_pt) { @return_to_for_test }
    controller.define_singleton_method(:jump_to_generated_url) { |*args, **kwargs| jumps << [args, kwargs] }
    controller.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    controller.define_singleton_method(:render) { |*args, **kwargs| renders << [args, kwargs] }
    controller.define_singleton_method(:head) { |status| heads << status }
    controller.define_singleton_method(:auth_com_sign_in_path) { |ri: nil| "/sign/in?ri=#{ri}" }
    controller.define_singleton_method(:auth_com_settings_path) { |ri: nil| "/settings?ri=#{ri}" }

    controller.instance_variable_set(:@logged_in_for_test, true)
    controller.instance_variable_set(:@restricted_for_test, true)

    assert_nil controller.send(:require_authentication_or_gate)

    controller.instance_variable_set(:@logged_in_for_test, false)
    controller.instance_variable_set(:@gate_for_test, true)
    session_hash[:pending_login_visitor_id] = @visitor.id

    assert_nil controller.send(:require_authentication_or_gate)

    controller.instance_variable_set(:@logged_in_for_test, true)
    controller.instance_variable_set(:@restricted_for_test, false)
    session_hash.delete(:pending_login_visitor_id)
    controller.send(:require_authentication_or_gate)

    assert_equal :forbidden, heads.last

    controller.instance_variable_set(:@logged_in_for_test, false)
    controller.instance_variable_set(:@gate_for_test, false)
    controller.send(:require_authentication_or_gate)

    assert_match "/sign/in?ri=jp", redirects.last.first.first

    controller.instance_variable_set(:@resource_for_test, @visitor)

    assert_equal @visitor, controller.send(:resolve_current_visitor)

    controller.instance_variable_set(:@resource_for_test, nil)
    session_hash[:pending_login_visitor_id] = @visitor.id

    assert_equal @visitor, controller.send(:resolve_current_visitor)

    controller.instance_variable_set(:@return_to_for_test, "/after")
    controller.send(:redirect_to_return_path, notice: "promoted")

    assert_equal [["/after"], { allow_other_host: false }], redirects.last
    assert_equal "promoted", flash_hash[:notice]

    controller.instance_variable_set(:@return_to_for_test, nil)
    controller.send(:redirect_to_return_path, notice: "promoted")

    assert_equal [["/settings?ri=jp"], { notice: "promoted" }], redirects.last

    active_token = create_active_session(@visitor)
    restricted_token = @token
    restricted_token.update!(visitor_token_status_id: VisitorTokenStatus::RESTRICTED)
    controller.instance_variable_set(:@session_for_test, restricted_token)

    assert_includes [true, false], controller.send(:can_promote_session?, @visitor)
    controller.send(:promote_current_session!)

    assert_equal VisitorTokenStatus::ACTIVE, restricted_token.reload.visitor_token_status_id

    controller.instance_variable_set(:@session_for_test, active_token)
    controller.send(:revoke_session_by_ref, @visitor, "bad-ref")

    assert_equal I18n.t("sign.app.in.session.invalid_session"), flash_hash[:alert]

    controller.send(:revoke_session_by_ref, @visitor, active_token.signed_ref)

    assert_equal I18n.t("sign.app.in.session.cannot_revoke_current"), flash_hash[:alert]

    controller.instance_variable_set(:@session_for_test, restricted_token)
    controller.send(:revoke_session_by_ref, @visitor, active_token.signed_ref)

    assert_equal I18n.t("sign.app.in.session.session_revoked"), flash_hash[:notice]
    assert active_token.reload.discarded_at

    batch_token = create_active_session(@visitor)
    controller.send(
      :revoke_sessions_by_refs, @visitor,
      [restricted_token.signed_ref, batch_token.signed_ref, "bad-ref"],
    )

    assert batch_token.reload.discarded_at
    assert_not_predicate restricted_token.reload, :revoked?

    controller.update

    assert_equal [[:show], { status: :unprocessable_content }], renders.last

    destroy_token = create_active_session(@visitor)
    controller.params[:ref] = destroy_token.signed_ref
    controller.destroy

    assert_equal [:show], renders.last.first

    controller.params.delete(:ref)
    controller.instance_variable_set(:@session_for_test, restricted_token.reload)
    controller.destroy

    assert controller.instance_variable_get(:@logged_out_for_test)
    assert_match "/sign/in?ri=jp", redirects.last.first.first
  end

  private

  def create_restricted_session(visitor)
    token = VisitorToken.create!(
      visitor: visitor,
      visitor_token_status_id: VisitorTokenStatus::RESTRICTED,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
    )
    token.rotate_refresh_token!
    token
  end

  def create_active_session(visitor)
    token = VisitorToken.create!(
      visitor: visitor,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      skip_session_limit_check: true,
    )
    token.rotate_refresh_token!
    token
  end

  def request_headers(token)
    {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => @visitor.id,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end

  def with_env(vars)
    original = {}
    vars.each_key { |key| original[key] = ENV[key] }

    vars.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end

    yield
  ensure
    original.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end

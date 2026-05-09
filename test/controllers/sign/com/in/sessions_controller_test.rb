# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::In::SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @customer = create_verified_customer_with_email(email_address: "sessions-#{SecureRandom.hex(4)}@example.com")
    @customer.customer_telephones.create!(
      number: "+10000000991",
      customer_telephone_status_id: CustomerTelephoneStatus::VERIFIED,
    )
    @token = create_restricted_session(@customer)
    satisfy_customer_verification(@token)
  end

  test "show redirects to login when not authenticated" do
    get sign_com_in_session_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :redirect
    assert_redirected_to %r{/sign/in/new\?ri=jp}
  end

  test "show with restricted session displays sessions" do
    create_active_session(@customer)
    headers = request_headers(@token)

    get sign_com_in_session_url(ri: "jp"), headers: headers

    assert_response :success
    assert_not response.redirect?
    assert_select "input[type=radio][name=ref]"
    assert_select "button", text: /キャンセルしてログアウト/
  end

  test "update without selections flashes alert and re-renders show" do
    headers = request_headers(@token)

    patch sign_com_in_session_url(ri: "jp"), params: { revoke_refs: [] }, headers: headers

    assert_response :unprocessable_content
  end

  test "update with ref param revokes specific session" do
    active_token = create_active_session(@customer)
    headers = request_headers(@token)

    patch sign_com_in_session_url(ri: "jp"), params: { ref: active_token.signed_ref }, headers: headers

    assert_response :redirect
    # Redirect to configuration because restricted session is promoted after revoking the only active session
    assert_match %r{/configuration\?ri=jp}, response.location
    assert_not_nil active_token.reload.lapses_at
    assert_equal CustomerToken::STATUS_ACTIVE, @token.reload.status
  end

  test "destroy without ref logs out and redirects to login" do
    headers = request_headers(@token)

    delete sign_com_in_session_url(ri: "jp"), headers: headers

    assert_response :redirect
    assert_match %r{/sign/in/new\?ri=jp}, response.location
  end

  test "direct controller session management branches" do
    controller = Sign::Com::In::SessionsController.new
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
    controller.define_singleton_method(:retrieve_redirect_parameter) { @redirect_parameter_for_test }
    controller.define_singleton_method(:session_limit_return_to) { @return_to_for_test }
    controller.define_singleton_method(:jump_to_generated_url) { |*args, **kwargs| jumps << [args, kwargs] }
    controller.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    controller.define_singleton_method(:render) { |*args, **kwargs| renders << [args, kwargs] }
    controller.define_singleton_method(:head) { |status| heads << status }
    controller.define_singleton_method(:new_sign_com_in_path) { |ri: nil| "/sign/in/new?ri=#{ri}" }
    controller.define_singleton_method(:sign_com_configuration_path) { |ri: nil| "/configuration?ri=#{ri}" }

    controller.instance_variable_set(:@logged_in_for_test, true)
    controller.instance_variable_set(:@restricted_for_test, true)

    assert_nil controller.send(:require_authentication_or_gate)

    controller.instance_variable_set(:@logged_in_for_test, false)
    controller.instance_variable_set(:@gate_for_test, true)
    session_hash[:pending_login_customer_id] = @customer.id

    assert_nil controller.send(:require_authentication_or_gate)

    controller.instance_variable_set(:@logged_in_for_test, true)
    controller.instance_variable_set(:@restricted_for_test, false)
    session_hash.delete(:pending_login_customer_id)
    controller.send(:require_authentication_or_gate)

    assert_equal :forbidden, heads.last

    controller.instance_variable_set(:@logged_in_for_test, false)
    controller.instance_variable_set(:@gate_for_test, false)
    controller.send(:require_authentication_or_gate)

    assert_match "/sign/in/new?ri=jp", redirects.last.first.first

    controller.instance_variable_set(:@resource_for_test, @customer)

    assert_equal @customer, controller.send(:resolve_current_customer)

    controller.instance_variable_set(:@resource_for_test, nil)
    session_hash[:pending_login_customer_id] = @customer.id

    assert_equal @customer, controller.send(:resolve_current_customer)

    controller.instance_variable_set(:@return_to_for_test, "/after")
    controller.send(:redirect_to_return_path, notice: "promoted")

    assert_equal [["/after"], { fallback: "/configuration?ri=" }], jumps.last
    assert_equal "promoted", flash_hash[:notice]

    controller.instance_variable_set(:@return_to_for_test, nil)
    controller.send(:redirect_to_return_path, notice: "promoted")

    assert_equal [["/configuration?ri=jp"], { notice: "promoted" }], redirects.last

    active_token = create_active_session(@customer)
    restricted_token = @token
    restricted_token.update!(status: CustomerToken::STATUS_RESTRICTED)
    controller.instance_variable_set(:@session_for_test, restricted_token)

    assert_includes [true, false], controller.send(:can_promote_session?, @customer)
    controller.send(:promote_current_session!)

    assert_equal CustomerToken::STATUS_ACTIVE, restricted_token.reload.status

    controller.instance_variable_set(:@session_for_test, active_token)
    controller.send(:revoke_session_by_ref, @customer, "bad-ref")

    assert_equal I18n.t("sign.app.in.session.invalid_session"), flash_hash[:alert]

    controller.send(:revoke_session_by_ref, @customer, active_token.signed_ref)

    assert_equal I18n.t("sign.app.in.session.cannot_revoke_current"), flash_hash[:alert]

    controller.instance_variable_set(:@session_for_test, restricted_token)
    controller.send(:revoke_session_by_ref, @customer, active_token.signed_ref)

    assert_equal I18n.t("sign.app.in.session.session_revoked"), flash_hash[:notice]
    assert active_token.reload.lapses_at

    batch_token = create_active_session(@customer)
    controller.send(
      :revoke_sessions_by_refs, @customer,
      [restricted_token.signed_ref, batch_token.signed_ref, "bad-ref"],
    )

    assert batch_token.reload.lapses_at
    assert_nil restricted_token.reload.lapses_at

    controller.update

    assert_equal [[:show], { status: :unprocessable_content }], renders.last

    destroy_token = create_active_session(@customer)
    controller.params[:ref] = destroy_token.signed_ref
    controller.destroy

    assert_equal [:show], renders.last.first

    controller.params.delete(:ref)
    controller.instance_variable_set(:@session_for_test, restricted_token.reload)
    controller.destroy

    assert controller.instance_variable_get(:@logged_out_for_test)
    assert_match "/sign/in/new?ri=jp", redirects.last.first.first
  end

  private

  def create_restricted_session(customer)
    token = CustomerToken.create!(
      customer: customer,
      status: CustomerToken::STATUS_RESTRICTED,
      customer_token_status_id: CustomerTokenStatus::NOTHING,
      customer_token_kind_id: CustomerTokenKind::BROWSER_WEB,
    )
    token.rotate_refresh_token!
    token
  end

  def create_active_session(customer)
    token = CustomerToken.create!(
      customer: customer,
      status: CustomerToken::STATUS_ACTIVE,
      customer_token_status_id: CustomerTokenStatus::NOTHING,
      customer_token_kind_id: CustomerTokenKind::BROWSER_WEB,
    )
    token.rotate_refresh_token!
    token
  end

  def request_headers(token)
    {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => @customer.id,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end
end

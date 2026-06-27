# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::Sign::In::SessionsControllerExtraTest < ActionDispatch::IntegrationTest
  fixtures :clients

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = clients(:one)
    ClientToken.where(user: @user).delete_all

    # Ensure necessary records exist
    Prosopite.pause do
      ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
      ClientTokenStatus::DEFAULTS.each do |id|
        ClientTokenStatus.find_or_create_by!(id: id)
      end
      ClientTokenBindingMethod.find_or_create_by!(id: 0) # NOTHING
      ClientTokenDbscStatus.find_or_create_by!(id: 0) # NOTHING
    end
  end

  test "update with single ref param revokes and stays on page if not promoted" do
    active1 = create_active_session(@user)
    create_active_session(@user)

    restricted = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, restricted, host: @host)

    # Bypass validation to create 3rd active
    active3 = ClientToken.new(
      user: @user,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discarded_at: 1.month.from_now,
    )
    active3.save!(validate: false)
    active3.rotate_refresh_token!

    patch sign_app_sign_in_session_url(ri: "jp"),
          params: { ref: active1.signed_ref },
          headers: headers

    assert_response :success
    assert_includes response.body, I18n.t("sign.app.in.session.session_revoked")

    restricted.reload

    assert_equal ClientTokenStatus::RESTRICTED, restricted.user_token_status_id
  end

  test "destroy with ref param revokes and stays on page" do
    active = create_active_session(@user)
    restricted = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, restricted, host: @host)

    delete sign_app_sign_in_session_url(ri: "jp"),
           params: { ref: active.signed_ref },
           headers: headers

    assert_response :success
    assert_includes response.body, I18n.t("sign.app.in.session.session_revoked")
    active.reload

    assert_not_nil active.discarded_at
  end

  test "pending cycle promotion consumes legacy gate but preserves pending actor id" do
    controller = Auth::App::Sign::In::SessionsController.new
    session_hash = {
      :pending_login_user_id => @user.id,
      SessionLimitGate::GATE_SESSION_KEY => {
        "nonce" => "legacy",
        "issued_at" => Time.current.to_i,
        "pt" => "/dashboard",
        "flow" => "in.email.session",
      },
    }
    redirects = []

    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) do
      ActionController::Parameters.new(revoke_refs: ["selected"], ri: "jp")
    end
    controller.define_singleton_method(:resolve_current_client) { @resolved_client }
    controller.define_singleton_method(:revoke_sessions_by_refs) { |_client, _refs| true }
    controller.define_singleton_method(:pending_session_limit_cycle?) { true }
    controller.define_singleton_method(:current_session_restricted?) { false }
    controller.define_singleton_method(:can_promote_session?) { |_client| true }
    controller.define_singleton_method(:promote_current_session_limit_cycle!) { |_client| true }
    controller.define_singleton_method(:consume_session_limit_gate!) { session.delete(SessionLimitGate::GATE_SESSION_KEY) }
    controller.define_singleton_method(:retrieve_pt) { nil }
    controller.define_singleton_method(:session_limit_pt) { "/dashboard" }
    controller.define_singleton_method(:redirect_to_sign_in_sequence!) { |**kwargs| redirects << kwargs }
    controller.instance_variable_set(:@resolved_client, @user)

    controller.update

    assert_equal [{ pt: "/dashboard", notice: I18n.t("sign.app.in.session.promoted") }], redirects
    assert_nil session_hash[SessionLimitGate::GATE_SESSION_KEY]
    assert_equal @user.id, session_hash[:pending_login_user_id]
  end

  private

  def create_restricted_session(user)
    token = ClientToken.new(
      user: user,
      user_token_status_id: ClientTokenStatus::RESTRICTED,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discarded_at: 1.month.from_now,
    )
    token.save!(validate: false)
    token.rotate_refresh_token!
    token
  end

  def create_active_session(user)
    token = ClientToken.new(
      user: user,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discarded_at: 1.month.from_now,
    )
    token.save!(validate: false)
    token.rotate_refresh_token!
    token
  end

  def as_user_headers_with_token(user, token, host:)
    access_token = AuthenticationToken.encode(user, host: host, session_public_id: token.public_id)
    {
      "Host" => host,
      "Authorization" => "Bearer #{access_token}",
      "Cookie" => "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{access_token}",
    }
  end
end

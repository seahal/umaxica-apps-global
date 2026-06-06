# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::In::GuardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @visitor = create_verified_visitor_with_email(email_address: "guard-#{SecureRandom.hex(4)}@example.com")
    VisitorSignInFlowStatus.ensure_defaults!
  end

  test "route resolves to guard controller" do
    route = Rails.application.routes.recognize_path("https://#{@host}/sign/in/guard", method: :get)

    assert_equal "sign/com/in/guards", route.fetch(:controller)
    assert_equal "show", route.fetch(:action)
  end

  test "guard state redirects to check without mutating durable rows or cycle state" do
    cycle = create_cycle(status: "GUARDRAIL_PENDING")
    before_attrs = guarded_cycle_attrs(cycle.reload)
    controller = build_controller(cycle: cycle)

    assert_no_sign_in_guard_durable_changes do
      controller.show
    end

    assert_equal "/sign/in/check?ri=jp", controller.redirected_to
    assert_equal before_attrs, guarded_cycle_attrs(cycle.reload)
  end

  test "checkpoint state redirects to check" do
    cycle = create_cycle(status: "CHECKPOINT_PENDING")
    before_attrs = guarded_cycle_attrs(cycle.reload)
    controller = build_controller(cycle: cycle)

    controller.show

    assert_equal "/sign/in/check?ri=jp", controller.redirected_to
    assert_equal before_attrs, guarded_cycle_attrs(cycle.reload)
  end

  test "session limit state redirects to session" do
    cycle = create_cycle(status: "SESSION_LIMIT_PENDING")
    before_attrs = guarded_cycle_attrs(cycle.reload)
    controller = build_controller(cycle: cycle)

    controller.show

    assert_equal "/sign/in/session?ri=jp", controller.redirected_to
    assert_equal before_attrs, guarded_cycle_attrs(cycle.reload)
  end

  test "selector state redirects to selector sequence path" do
    cycle = create_cycle(status: "SELECTOR_PENDING", return_to: "/dashboard")
    controller = build_controller(cycle: cycle)

    controller.show

    assert_equal "/sign/in/selector?pt=/dashboard", controller.redirected_to
  end

  test "later state redirects to welcome sequence path" do
    cycle = create_cycle(status: "DASHBOARD_PENDING", return_to: "/dashboard")
    controller = build_controller(cycle: cycle)

    controller.show

    assert_equal "/sign/in/welcome?pt=/dashboard", controller.redirected_to
  end

  test "unsafe path target redirects to sign in entry without flash" do
    cycle = create_cycle(status: "CHECKPOINT_PENDING")
    controller = build_controller(cycle: cycle, path_target: "/account", signed_pt: nil)

    controller.show

    assert_equal "/sign/in/new?ri=jp", controller.redirected_to
    assert_equal "CHECKPOINT_PENDING", cycle.reload.state
  end

  test "unsafe return target redirects to sign in entry without flash" do
    cycle = create_cycle(status: "CHECKPOINT_PENDING", return_to: "https://evil.example.test")
    controller = build_controller(cycle: cycle, signed_token: nil)

    controller.show

    assert_equal "/sign/in/new?ri=jp", controller.redirected_to
    assert_equal "CHECKPOINT_PENDING", cycle.reload.state
  end

  test "missing or expired cycle redirects to sign in entry without flash" do
    get sign_com_in_guard_url(ri: "jp"), headers: host_headers(@host)

    assert_redirected_to new_sign_com_sign_in_url(ri: "jp")
    assert_empty flash.to_hash
  end

  private

  def create_cycle(status:, issued_at: Time.current, expires_at: 15.minutes.from_now, return_to: nil)
    VisitorSignInFlow.create!(
      principal_id: @visitor.id,
      status_id: VisitorSignInFlow.status_id_for(status),
      state: status,
      step: step_for(status),
      nonce_digest: VisitorSignInFlow.digest_nonce("pending-test-nonce"),
      issued_at: issued_at,
      expires_at: expires_at,
      return_to: return_to,
    )
  end

  def build_controller(cycle:, path_target: nil, signed_pt: nil, signed_token: "signed-pt")
    controller = Sign::Com::In::GuardsController.new
    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp") }
    controller.define_singleton_method(:path_target_value) { path_target }
    controller.define_singleton_method(:signed_pt_param) { signed_pt }
    controller.define_singleton_method(:signed_pt_token) { |path| path.presence && signed_token }
    controller.define_singleton_method(:path_from_signed_pt) { |_| path_target }
    controller.define_singleton_method(:current_db_sign_in_flow_for_sequence) { cycle }
    controller.define_singleton_method(:sign_in_flow_actor) { |_| @visitor }
    controller.define_singleton_method(:sign_com_sign_in_entrance_path) { |ri: nil| "/sign/in/new?ri=#{ri}" }
    controller.define_singleton_method(:sign_com_in_check_path) { |ri: nil, pt: nil|
      "/sign/in/check?ri=#{ri}#{pt ? "&pt=#{pt}" : ""}"
    }
    controller.define_singleton_method(:sign_com_in_session_path) { |ri: nil, pt: nil|
      "/sign/in/session?ri=#{ri}#{pt ? "&pt=#{pt}" : ""}"
    }
    controller.define_singleton_method(:sign_in_selector_path) { |pt: nil| "/sign/in/selector?pt=#{pt}" }
    controller.define_singleton_method(:sign_in_welcome_path) { |pt: nil| "/sign/in/welcome?pt=#{pt}" }
    controller.define_singleton_method(:redirect_to) { |path, **_options| @redirected_to = path }
    controller.define_singleton_method(:redirected_to) { @redirected_to }
    controller
  end

  def step_for(status)
    VisitorSignInFlow::STEP_BY_STATUS_ID.fetch(VisitorSignInFlow.status_id_for(status))
  end

  def guarded_cycle_attrs(cycle)
    cycle.attributes.slice("status_id", "state", "step", "token_id", "completed_at", "session_issued_at")
  end

  def assert_no_sign_in_guard_durable_changes(&)
    assert_no_difference("Visitor.count") do
      assert_no_difference("VisitorAccount.count") do
        assert_no_difference("Organization.count") do
          assert_no_difference("Avatar.count") do
            assert_no_difference("VisitorToken.count") do
              assert_no_difference("VisitorSignUpFlow.count", &)
            end
          end
        end
      end
    end
  end
end

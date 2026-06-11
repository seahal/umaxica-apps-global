# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthenticationSequenceGateExtraCoverageTest < ActiveSupport::TestCase
  class Result < Struct.new(:blocking)
    def blocking?
      blocking
    end
  end

  class FakeCycle
    attr_accessor :return_to, :public_id, :states

    def initialize(return_to: "/return", public_id: "seq-1", states: {})
      @return_to = return_to
      @public_id = public_id
      @states = states
    end

    def sign_in_session_limit_pending? = states[:session_limit]
    def sign_in_checkpoint_pending? = states[:checkpoint]
    def sign_in_selector_pending? = states[:selector]
    def sign_in_completed? = states[:completed]
    def sign_in_guardrail_pending? = states[:guardrail]
    def sign_in_dashboard_pending? = states[:dashboard]
    def sign_in_return_pending? = states[:return_pending]

    def reload = self

    def has_attribute?(name)
      name == :token_id
    end

    def token_id
      states[:token_id]
    end

    def update!(*)
      true
    end

    def status_id_for(_value)
      "dashboard-pending"
    end
  end

  class GuardrailParticipant
    def initialize(result)
      @result = result
    end

    def advance_if_clear!
      @result
    end
  end

  class CheckpointParticipant
    def initialize(result)
      @result = result
    end

    def advance_if_clear!
      @result
    end
  end

  class Harness
    include AuthenticationSequenceGate

    attr_accessor :session_hash, :params_hash, :request_obj, :rendered, :redirected, :current_resource,
                  :cycle, :guardrail_result, :checkpoint_result, :allowed_policy, :current_session_value,
                  :selector_result

    def initialize
      @session_hash = {}
      @params_hash = { ri: "jp" }
      @request_obj = Struct.new(:path, :format).new("/selector", Struct.new(:html?).new(true))
      @cycle = nil
      @guardrail_result = Result.new(false)
      @checkpoint_result = Result.new(false)
      @selector_result = { status: :success }
    end

    def session = @session_hash
    def params = @params_hash.with_indifferent_access
    def request = @request_obj
    def current_resource
      @current_resource
    end

    def current_resource=(value)
      @current_resource = value
    end
    def logged_in? = current_resource.present?
    def current_session
      @current_session_value
    end

    def current_session=(value)
      @current_session_value = value
    end
    def after_dashboard_path = "/dashboard"
    def after_welcome_path = "/welcome"
    def after_login_allows_other_host? = false
    def redirect_to(path, **kwargs) = @redirected = [path, kwargs]
    def render(**kwargs) = @rendered = kwargs
    def sign_in_sequence_surface = :app
    def signed_pt_token(value) = value ? "pt:#{value}" : nil
    def path_from_signed_pt(value) = value&.sub(/\Apt:/, "")
    def clear_welcome_gate! = session.delete(welcome_gate_key)
    def clear_current_sign_in_flow_locator! = (@locator_cleared = true)
    def allow_to?(rule, *_args)
      return @allowed_policy.fetch(rule) if @allowed_policy.is_a?(Hash)
      return @allowed_policy unless @allowed_policy.nil?

      true
    end
    alias allowed_to? allow_to?

    def current_db_sign_in_flow_for_sequence = @cycle
    def sign_in_sequence_carrier
      @sign_in_sequence_carrier ||= Struct.new(:current) do
        def start!(**kwargs)
          self.current = Struct.new(:id).new(kwargs[:state] || "seq-1")
          current
        end
      end.new(nil)
    end
    def with_sign_in_flow_writing(_cycle)
      yield
    end
    def sign_in_guardrail_participant(_cycle) = GuardrailParticipant.new(@guardrail_result)
    def sign_in_checkpoint_participant(_cycle) = CheckpointParticipant.new(@checkpoint_result)
    def sign_in_dashboard_participant(_cycle) = GuardrailParticipant.new(@guardrail_result)
    def sign_in_flow_actor(_cycle) = current_resource
    def issue_active_session_for_selector!(_cycle) = @selector_result
    def reset_current_db_sign_in_flow_for_sequence! = (@cycle = nil)
    def sign_in_flow_locator_for(*)
      Struct.new(:issued, :cleared) do
        def issue!(_cycle) = self.issued = true
        def clear! = self.cleared = true
      end.new(false, false)
    end
    def sign_in_selector_path(pt: nil) = super
    def sign_in_session_limit_path(pt: nil) = super
    def sign_in_checkpoint_path(pt: nil) = "/checkpoint?pt=#{pt}"
    def sign_in_welcome_path(pt: nil) = "/welcome?pt=#{pt}"
    def sign_app_sign_in_session_path(**attrs) = "/app/session?#{attrs.compact.to_query}"
    def sign_app_selector_path(**attrs) = "/app/selector?#{attrs.compact.to_query}"
    def sign_in_sequence_required_for_participant?(_participant) = true
    def bulletin_state = nil
    def controller_path = "sign/app/checkpoints"
    def log_in(*)
      { status: :success }
    end
  end

  class FallbackHarness < Harness
    undef_method :sign_app_sign_in_session_path
    undef_method :sign_app_selector_path
  end

  setup do
    @harness = Harness.new
  end

  test "sign_in_session_limit_path prefers surface helper and falls back to generic path" do
    assert_equal "/app/session?pt=pt%3Atarget&ri=jp", @harness.sign_in_session_limit_path(pt: "target")

    fallback = FallbackHarness.new

    assert_equal "/in/session?pt=pt%3Atarget&ri=jp", fallback.sign_in_session_limit_path(pt: "target")
  end

  test "sign_in_selector_path falls back to the generic selector path" do
    fallback = FallbackHarness.new

    assert_equal "/selector?pt=pt%3Atarget&ri=jp", fallback.sign_in_selector_path(pt: "target")
  end

  test "issue_welcome_gate_and_path sets the gate and clears previous state" do
    @harness.session[@harness.send(:welcome_gate_key)] = { "remaining" => 1 }

    path = @harness.send(:issue_welcome_gate_and_path, pt: "/after", sequence_id: "seq-1")

    assert_equal "/welcome?pt=/after", path
    gate = @harness.session[@harness.send(:welcome_gate_key)]
    assert_equal 5, gate["remaining"]
    assert_equal "seq-1", gate["sequence_id"]
  end

  test "consume_welcome_gate! rejects invalid and mismatched gates and decrements valid ones" do
    gate_key = @harness.send(:welcome_gate_key)

    @harness.session[gate_key] = "bad"
    assert_not @harness.send(:consume_welcome_gate!)

    @harness.session[gate_key] = { "remaining" => 1, "expires_at" => 1.minute.ago.to_i }
    assert_not @harness.send(:consume_welcome_gate!)

    @harness.session[gate_key] = { "remaining" => 1, "expires_at" => 1.minute.from_now.to_i, "sequence_id" => "seq-x" }
    assert_not @harness.send(:consume_welcome_gate!, sequence_id: "seq-y")

    @harness.session[gate_key] = { "remaining" => 2, "expires_at" => 1.minute.from_now.to_i, "sequence_id" => "seq-y" }
    assert @harness.send(:consume_welcome_gate!, sequence_id: "seq-y")
    assert_equal 1, @harness.session[gate_key]["remaining"]
  end

  test "sign_in_sequence_redirect_path follows cycle state branches" do
    @harness.cycle = FakeCycle.new(states: { session_limit: true })
    assert_equal "/app/session?pt=pt%3Apt%3A%2Freturn&ri=jp", @harness.sign_in_sequence_redirect_path

    @harness.cycle = FakeCycle.new(states: { checkpoint: true })
    assert_equal "/checkpoint?pt=pt:/return", @harness.sign_in_sequence_redirect_path

    @harness.cycle = FakeCycle.new(states: { selector: true })
    assert_equal "/app/selector?pt=pt%3Apt%3A%2Freturn&ri=jp", @harness.sign_in_sequence_redirect_path

    @harness.cycle = FakeCycle.new(states: { completed: true })
    assert_equal "/welcome?pt=pt:/return", @harness.sign_in_sequence_redirect_path

    @harness.cycle = FakeCycle.new(states: { guardrail: false })
    assert_equal "/dashboard", @harness.sign_in_sequence_redirect_path

    @harness.cycle = FakeCycle.new(states: { guardrail: true })
    assert_equal "/checkpoint?pt=pt:/return", @harness.sign_in_sequence_redirect_path
  end

  test "begin_sign_in_sequence! returns a success result when current resource is present" do
    @harness.current_resource = Client.new(id: 123)
    @harness.current_session = Struct.new(:id).new(1)

    actor_authn = Struct.new(:amr).new(["pwd"])

    Actor.stub(:authn, actor_authn) do
      result = @harness.send(:begin_sign_in_sequence!, pt: "/settings", checkpoint_required: true)

      assert_equal :success, result.status
      assert_equal 123, result.actor.id
      assert_equal :found, result.response_status
    end
  end

  test "require_sign_in_sequence_participant! renders bad request when policy denies" do
    sequence = Struct.new(:expired?, :state, :actor_type).new(false, "CHECKPOINT_PENDING", "client")
    @harness.allowed_policy = false
    carrier = Class.new do
      attr_accessor :current, :expired, :failed

      def initialize(sequence)
        @current = sequence
      end

      def expire!
        @expired = true
      end

      def fail!
        @failed = true
      end
    end.new(sequence)
    @harness.instance_variable_set(:@sign_in_sequence_carrier, carrier)

    assert_not @harness.send(:require_sign_in_sequence_participant!, participant: :checkpoint, policy_rule: :show_checkpoint?)
    assert_equal :bad_request, @harness.rendered[:status]
  end

  test "enforce_sign_in_selector_gate! renders forbidden for json and redirects for html" do
    @harness.current_resource = Client.new
    @harness.cycle = FakeCycle.new(states: { selector: true })
    @harness.request.format = Struct.new(:html?).new(false)
    @harness.request.path = "/blocked"
    @harness.define_singleton_method(:sign_in_selector_allowed_request?) { false }

    @harness.enforce_sign_in_selector_gate!

    assert_equal :forbidden, @harness.rendered[:status]

    @harness.request.format = Struct.new(:html?).new(true)
    @harness.rendered = nil

    @harness.enforce_sign_in_selector_gate!

    assert_equal ["/app/selector?pt=pt%3A%2Freturn&ri=jp", {}], @harness.redirected
  end

  test "current_db_sign_in_flow_for_sequence returns nil when locator raises argument error" do
    @harness.define_singleton_method(:current_session) { raise ArgumentError }

    assert_nil @harness.send(:current_db_sign_in_flow_for_sequence)
  end
end

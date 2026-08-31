# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

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

    def redirect_to_jump_url(url, **kwargs) = @redirected = ["jump:#{url}", kwargs]

    def render(**kwargs) = @rendered = kwargs

    def sign_in_sequence_surface = :app

    def current_region_identifier
      RequestContextContract.normalize_region(params[:ri])
    end

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

    def bulletin_state = session[:sign_in_checkpoint]

    def controller_path = "sign/app/checkpoints"

    def log_in(*)
      { status: :success }
    end
  end

  class ExternalDashboardHarness < Harness
    def after_dashboard_path = "https://www.umaxica.app/dashboard?ri=jp"
  end

  class FallbackHarness < Harness
    undef_method :sign_app_sign_in_session_path
    undef_method :sign_app_selector_path
  end

  class OrgHarness < Harness
    undef_method :sign_app_sign_in_session_path
    undef_method :sign_app_selector_path

    def sign_org_sign_in_session_path(**attrs) = "/org/session?#{attrs.compact.to_query}"

    def sign_org_selector_path(**attrs) = "/org/selector?#{attrs.compact.to_query}"
  end

  class ComHarness < Harness
    undef_method :sign_app_sign_in_session_path
    undef_method :sign_app_selector_path

    def sign_com_sign_in_session_path(**attrs) = "/com/session?#{attrs.compact.to_query}"

    def sign_com_selector_path(**attrs) = "/com/selector?#{attrs.compact.to_query}"
  end

  class LocatorHarness < Harness
    attr_accessor :surface

    def sign_in_sequence_surface = surface

    def current_db_sign_in_flow_for_sequence
      AuthenticationSequenceGate.instance_method(:current_db_sign_in_flow_for_sequence).bind(self).call
    end
  end

  setup do
    @harness = Harness.new
  end

  test "sign_in_session_limit_path prefers surface helper and falls back to generic path" do
    assert_equal "/app/session?pt=pt%3Atarget&ri=jp", @harness.sign_in_session_limit_path(pt: "target")

    fallback = FallbackHarness.new

    assert_equal "/in/session?pt=pt%3Atarget&ri=jp", fallback.sign_in_session_limit_path(pt: "target")

    assert_equal "/org/session?pt=pt%3Atarget&ri=jp", OrgHarness.new.sign_in_session_limit_path(pt: "target")
    assert_equal "/com/session?pt=pt%3Atarget&ri=jp", ComHarness.new.sign_in_session_limit_path(pt: "target")
  end

  test "legacy bulletin session state does not hold an otherwise clear checkpoint" do
    @harness.cycle = FakeCycle.new(states: { checkpoint: true })
    @harness.session[:sign_in_checkpoint] = { "kind" => "checkpoint", "state" => "new" }

    @harness.continue_checkpoint_sequence_without_content!

    assert_equal ["/welcome?pt=/return", { allow_other_host: false }], @harness.redirected
  end

  test "sign_in_selector_path falls back to the generic selector path" do
    fallback = FallbackHarness.new

    assert_equal "/selector?pt=pt%3Atarget&ri=jp", fallback.sign_in_selector_path(pt: "target")

    assert_equal "/org/selector?pt=pt%3Atarget&ri=jp", OrgHarness.new.sign_in_selector_path(pt: "target")
    assert_equal "/com/selector?pt=pt%3Atarget&ri=jp", ComHarness.new.sign_in_selector_path(pt: "target")
  end

  test "sign-in helper paths canonicalize invalid region input" do
    harness = FallbackHarness.new
    harness.params_hash = { ri: "https://evil.example" }

    assert_equal "/in/session?pt=pt%3Atarget&ri=jp", harness.sign_in_session_limit_path(pt: "target")
    assert_equal "/selector?pt=pt%3Atarget&ri=jp", harness.sign_in_selector_path(pt: "target")
  end

  test "redirect_to_sign_in_sequence! uses jump gateway for absolute destinations" do
    harness = ExternalDashboardHarness.new
    harness.define_singleton_method(:sign_in_sequence_redirect_path) do |pt: nil, default_path: after_dashboard_path|
      _ = pt
      _ = default_path
      "https://www.umaxica.app/dashboard?ri=jp"
    end

    harness.redirect_to_sign_in_sequence!

    assert_equal ["jump:https://www.umaxica.app/dashboard?ri=jp", {}], harness.redirected
  end

  test "redirect_to_sign_in_sequence! keeps internal paths local" do
    @harness.define_singleton_method(:sign_in_sequence_redirect_path) do |pt: nil, default_path: after_dashboard_path|
      _ = pt
      _ = default_path
      "/app/session?pt=pt%3Atarget&ri=jp"
    end

    @harness.redirect_to_sign_in_sequence!(pt: "target")

    assert_equal ["/app/session?pt=pt%3Atarget&ri=jp", { allow_other_host: false }], @harness.redirected
  end

  test "redirect_after_checkpoint_sequence! never permits an external host" do
    @harness.define_singleton_method(:dashboard_sequence_step_required?) { false }

    @harness.redirect_after_checkpoint_sequence!(
      default_path: "https://evil.example/dashboard",
      allow_other_host: true,
      status: :see_other,
    )

    assert_equal [
      "https://evil.example/dashboard",
      { allow_other_host: false, status: :see_other },
    ], @harness.redirected
  end

  test "redirect_after_checkpoint_sequence! rejects, blocks, or advances a pending checkpoint cycle" do
    @harness.cycle = FakeCycle.new(states: { checkpoint: false })

    @harness.redirect_after_checkpoint_sequence!

    assert_equal :bad_request, @harness.rendered[:status]

    @harness.cycle = FakeCycle.new(states: { checkpoint: true }, return_to: "/after")
    @harness.allowed_policy = false

    @harness.redirect_after_checkpoint_sequence!

    assert_equal :bad_request, @harness.rendered[:status]

    @harness.cycle = FakeCycle.new(states: { checkpoint: true }, return_to: "/after")
    @harness.allowed_policy = true
    @harness.checkpoint_result = Result.new(true)

    @harness.redirect_after_checkpoint_sequence!(pt: "fallback")

    assert_equal ["/checkpoint?pt=/after", { allow_other_host: false }], @harness.redirected

    @harness.cycle = FakeCycle.new(states: { checkpoint: true }, return_to: "/after")
    @harness.checkpoint_result = Result.new(false)

    @harness.redirect_after_checkpoint_sequence!(pt: "fallback")

    assert_equal "/app/selector?pt=pt%3A%2Fafter&ri=jp", @harness.redirected.first
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

    @harness.session[gate_key] = { "remaining" => 0, "expires_at" => 1.minute.from_now.to_i }

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

  test "continue_selector_sequence! rejects, advances, and rescues selector participant errors" do
    assert_not @harness.continue_selector_sequence!
    assert_equal :bad_request, @harness.rendered[:status]

    @harness.cycle = FakeCycle.new(states: { selector: false })

    assert_not @harness.continue_selector_sequence!
    assert_equal :bad_request, @harness.rendered[:status]

    @harness.cycle = FakeCycle.new(states: { selector: true })
    @harness.allowed_policy = false

    assert_not @harness.continue_selector_sequence!
    assert_equal :bad_request, @harness.rendered[:status]

    @harness.cycle = FakeCycle.new(states: { selector: true }, return_to: "/after")
    @harness.allowed_policy = true
    @harness.current_resource = Client.new(id: 123)
    actor_authn = Struct.new(:login_public_id).new("login-1")

    Actor.stub(:authn, actor_authn) do
      SignInSelectorParticipant.stub(:new, Struct.new(:auto_commit_single!).new(true)) do
        @harness.selector_result = { status: :success }

        @harness.continue_selector_sequence!

        assert_equal "/welcome?pt=/after", @harness.redirected.first
      end

      @harness.cycle = FakeCycle.new(states: { selector: true }, return_to: "/after")
      SignInSelectorParticipant.stub(:new, Struct.new(:auto_commit_single!).new(true)) do
        @harness.selector_result = { status: :failed }

        assert_not @harness.continue_selector_sequence!
        assert_equal :bad_request, @harness.rendered[:status]
      end

      @harness.cycle = FakeCycle.new(states: { selector: true }, return_to: "/after")
      raiser = Object.new
      raiser.define_singleton_method(:auto_commit_single!) { raise SignInSelectorParticipant::Error, "boom" }
      SignInSelectorParticipant.stub(:new, raiser) do
        assert_not @harness.continue_selector_sequence!
        assert_equal :bad_request, @harness.rendered[:status]
      end
    end
  end

  test "dashboard_sequence_step_required? and sign_in_sequence_required_for_participant? default to true" do
    plain_harness = Class.new { include AuthenticationSequenceGate }.new

    assert plain_harness.send(:dashboard_sequence_step_required?)
    assert plain_harness.send(:sign_in_sequence_required_for_participant?, :checkpoint)
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

    assert_not @harness.send(
      :require_sign_in_sequence_participant!, participant: :checkpoint,
                                              policy_rule: :show_checkpoint?,
    )
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

  test "current_db_sign_in_flow_for_sequence resolves pending actors before token issuance" do
    [
      [:app, Client.create!(public_id: "u_#{SecureRandom.hex(6)}", status_id: ClientStatus::ACTIVE),
       ClientSignInFlow, :pending_login_user_id,],
      [:com, Visitor.create!(public_id: "v_#{SecureRandom.hex(6)}", status_id: VisitorStatus::ACTIVE),
       VisitorSignInFlow, :pending_login_visitor_id,],
      [:org, Operator.create!(status_id: OperatorStatus::ACTIVE),
       OperatorSignInFlow, :pending_login_staff_id,],
    ].each do |surface, actor, cycle_class, pending_key|
      harness = LocatorHarness.new
      harness.surface = surface
      cycle = create_session_limit_cycle(cycle_class, actor)

      SignInCycleLocator.new(harness.session, surface: surface, actor: actor).issue!(cycle, nonce: "pending-#{surface}")
      harness.session[pending_key] = actor.id

      assert_equal cycle, harness.send(:current_db_sign_in_flow_for_sequence)
    end
  end

  test "continue_checkpoint_sequence_without_content! advances a checkpoint cycle" do
    @harness.current_resource = Client.new(id: 123)
    @harness.cycle = FakeCycle.new(states: { checkpoint: true, dashboard: true }, return_to: "/after")
    @harness.checkpoint_result = Result.new(false)

    issued = []
    @harness.define_singleton_method(:issue_welcome_gate_and_path) do |pt:, sequence_id:|
      issued << [pt, sequence_id]
      "/welcome?pt=#{pt}"
    end

    @harness.continue_checkpoint_sequence_without_content!

    assert_equal [["/after", "seq-1"]], issued
    assert_equal "/welcome?pt=/after", @harness.redirected.first
  end

  test "continue_checkpoint_sequence_without_content! redirects to after_login_path for an OIDC login challenge" do
    @harness.current_resource = Client.new(id: 123)
    @harness.cycle = FakeCycle.new(states: { checkpoint: true, dashboard: true }, return_to: "/after")
    @harness.checkpoint_result = Result.new(false)
    @harness.session[:oidc_authorization_login_challenge] = "challenge-1"
    @harness.define_singleton_method(:after_login_path) { "/after-login" }

    @harness.continue_checkpoint_sequence_without_content!

    assert_equal ["/after-login", { allow_other_host: false }], @harness.redirected
  end

  test "continue_welcome_sequence_without_content! handles non-cycle and cycle paths" do
    carrier =
      Struct.new(:current, :completed, :cleared) do
        def complete!
          self.completed = true
        end

        def clear!
          self.cleared = true
        end
      end.new(Struct.new(:participant).new("dashboard"), false, false)
    @harness.instance_variable_set(:@sign_in_sequence_carrier, carrier)
    @harness.define_singleton_method(:welcome_gate_available?) { true }
    @harness.define_singleton_method(:consume_welcome_gate!) { |**| true }
    @harness.define_singleton_method(:path_target_value) { "/after" }
    @harness.define_singleton_method(:clear_welcome_gate!) { @cleared = true }

    @harness.continue_welcome_sequence_without_content!

    assert carrier.completed
    assert carrier.cleared
    assert_equal "/after", @harness.instance_variable_get(:@welcome_next_path)
  end

  test "start_sign_in_flow_for! stores a cycle with the derived return path" do
    cycle_class =
      Class.new do
        class << self
          def created
            @created
          end

          def created=(val)
            @created = val
          end
        end

        def self.create!(**attrs)
          self.created = attrs
          Struct.new(:id).new(77)
        end

        def self.status_id_for(value)
          "status:#{value}"
        end

        def self.digest_nonce(nonce)
          "digest:#{nonce}"
        end
      end

    @harness.define_singleton_method(:sign_in_flow_class_for) { |_resource| cycle_class }
    @harness.define_singleton_method(:path_from_signed_pt) { |value| value&.sub(/\Apt:/, "") }
    @harness.define_singleton_method(:signed_pt_token) { |value| value && "pt:#{value}" }

    result = @harness.send(:start_sign_in_flow_for!, Client.new(id: 42), pt: "/return")

    created = cycle_class.created

    assert_equal 42, created[:principal_id]
    assert_equal "/return", created[:return_to]
    assert_equal "status:PRIMARY_PENDING", created[:status_id]
    assert_equal 77, result.id
  end

  test "bind_current_session_to_sign_in_flow! skips completed tokens and binds missing ones" do
    cycle = Struct.new(:token_id, :session_issued_at, :updated) do
      def has_attribute?(name)
        %i(token_id session_issued_at).include?(name)
      end

      def reload
        self
      end

      def update!(changes)
        self.updated = changes
      end
    end.new(nil, nil, nil)

    @harness.current_session = "session-1"
    @harness.send(:bind_current_session_to_sign_in_flow!, cycle)

    assert_equal "session-1", cycle.updated[:token]
  end

  test "sign_in_selector_allowed_request? accepts allowed routes and rejects invalid paths" do
    @harness.request.path = "/app/selector"

    assert @harness.send(:sign_in_selector_allowed_request?)

    @harness.request.path = "/unrelated"
    @harness.define_singleton_method(:sign_app_selector_path) { |**| "http://[" }

    assert_not @harness.send(:sign_in_selector_allowed_request?)
  end

  test "sign_in_sequence_surface_for_actor and sign_in_flow_class_for resolve actor types" do
    assert_equal :app, @harness.send(:sign_in_sequence_surface_for_actor, Client.new)
    assert_equal :com, @harness.send(:sign_in_sequence_surface_for_actor, Visitor.new)
    assert_equal :org, @harness.send(:sign_in_sequence_surface_for_actor, Operator.new)
    assert_equal :app, @harness.send(:sign_in_sequence_surface_for_actor, Object.new)

    assert_equal ClientSignInFlow, @harness.send(:sign_in_flow_class_for, Client.new)
    assert_equal VisitorSignInFlow, @harness.send(:sign_in_flow_class_for, Visitor.new)
    assert_equal OperatorSignInFlow, @harness.send(:sign_in_flow_class_for, Operator.new)

    assert_raises(ArgumentError) do
      @harness.send(:sign_in_flow_class_for, Object.new)
    end
  end

  test "issue_active_session_for_selector! issues a session and persists the cycle" do
    cycle_class =
      Class.new do
        class << self
          def transaction
            yield
          end
        end

        attr_reader :updates, :locks, :completed

        def initialize
          @updates = []
          @locks = 0
          @completed = false
        end

        def lock!
          @locks += 1
        end

        def sign_in_completed?
          false
        end

        def sign_in_session_issuance_pending?
          true
        end

        def has_attribute?(name)
          name == :session_issued_at
        end

        def token_id
          nil
        end

        def update!(changes)
          @updates << changes
        end

        def complete_sign_in!
          @completed = true
        end
      end

    cycle = cycle_class.new
    actor = Client.new(id: 101)

    @harness.define_singleton_method(:sign_in_flow_actor) { |_cycle| actor }

    result = AuthenticationSequenceGate.instance_method(:issue_active_session_for_selector!).bind(@harness).call(cycle)

    assert_equal({ status: :success }, result)
    assert_equal 1, cycle.updates.length
    assert_predicate cycle, :completed
    assert_equal({ token: nil }, cycle.updates.first.slice(:token))
    assert_predicate cycle.updates.first[:session_issued_at], :present?
  end

  # The OIDC hand-off promotes a session-limited cycle only once every participant
  # ahead of the hand-off has cleared. A blocking guardrail or checkpoint stops it,
  # and the caller treats that as "do not hand off".
  test "advance_oidc_session_promotion stops at a blocking guardrail" do
    cycle = FakeCycle.new(states: { guardrail: true })
    @harness.guardrail_result = Result.new(true)

    SignInGuardrailParticipant.stub(:new, GuardrailParticipant.new(Result.new(true))) do
      assert_not @harness.send(:advance_oidc_session_promotion!, cycle, Object.new)
    end
  end

  test "advance_oidc_session_promotion stops at a blocking checkpoint" do
    cycle = FakeCycle.new(states: { guardrail: false, checkpoint: true })
    @harness.checkpoint_result = Result.new(true)

    assert_not @harness.send(:advance_oidc_session_promotion!, cycle, Object.new)
  end

  test "advance_oidc_session_promotion clears when no participant blocks" do
    cycle = FakeCycle.new(states: { guardrail: true, checkpoint: true })
    @harness.checkpoint_result = Result.new(false)

    SignInGuardrailParticipant.stub(:new, GuardrailParticipant.new(Result.new(false))) do
      assert @harness.send(:advance_oidc_session_promotion!, cycle, Object.new)
    end
  end

  private

  def create_session_limit_cycle(cycle_class, actor)
    cycle_class.create!(
      principal_id: actor.id,
      status_id: cycle_class.status_id_for("SESSION_LIMIT_PENDING"),
      state: "SESSION_LIMIT_PENDING",
      step: "session_limit",
      return_to: "/dashboard",
      nonce_digest: cycle_class.digest_nonce("unused"),
      issued_at: Time.current,
      expires_at: 15.minutes.from_now,
    )
  end
end

# DAMP local route helper aliases for former shared test support.
class AuthenticationSequenceGateExtraCoverageTest
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

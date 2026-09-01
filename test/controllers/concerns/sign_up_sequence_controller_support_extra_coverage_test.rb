# typed: false
# frozen_string_literal: true

require "test_helper"

class SignUpSequenceControllerSupportExtraCoverageTest < ActiveSupport::TestCase
  # Stands in for SignUpSessionState, which is backed by the real session store.
  # `age_restricted` needs both a reader and a writer because the concern sets it.
  class SessionState
    attr_writer :age_restricted
    attr_reader :cleared

    def initialize(age_restricted: false)
      @age_restricted = age_restricted
      @cleared = false
    end

    def age_restricted? = @age_restricted

    def clear!
      @cleared = true
    end

    def clear_all! = clear!
  end

  class Harness
    include SignUpSequenceControllerSupport

    attr_accessor :params_hash, :session_hash, :rendered, :redirected, :performed_value,
                  :allowed_value, :surface_value, :ticket, :locator_current, :sequence_id,
                  :actor_value, :missing_requirements_value, :completed_requirements_value,
                  :handoff_pt_value, :recovery_url_value
    attr_writer :sign_up_session_state_value

    def initialize
      @params_hash = {}
      @session_hash = {}
      @rendered = nil
      @redirected = nil
      @performed_value = false
      @allowed_value = nil
      @surface_value = :app
      @ticket = nil
      @locator_current = nil
      @sequence_id = nil
      @actor_value = nil
      @missing_requirements_value = []
      @completed_requirements_value = []
      @handoff_pt_value = nil
      @recovery_url_value = nil
    end

    def params = ActionController::Parameters.new(params_hash || {})

    def session = @session_hash

    def request
      @request ||= Struct.new(:format).new(Struct.new(:json?, :html?).new(false, true))
    end

    def response
      @response ||= Struct.new(:headers).new({})
    end

    def render(*args, **kwargs)
      self.rendered = [args, kwargs]
    end

    def redirect_to(*args, **kwargs)
      self.redirected = [args, kwargs]
    end

    def performed?
      performed_value || false
    end

    def allowed_to?(*)
      return allowed_value unless allowed_value.nil?

      true
    end

    def sign_up_surface = surface_value || :app

    def sign_up_session_state
      @sign_up_session_state_value ||= SessionState.new
    end

    def sign_up_flow_locator
      Struct.new(:current).new(locator_current)
    end

    def sign_up_ticket_class
      Class.new do
        def self.find_by(*) = nil
      end
    end

    def sign_up_sequence_session_key = :auth_app_up_sequence_id

    def sign_up_ticket_record_class
      @sign_up_ticket_record_class_value ||=
        Class.new do
          def self.connected_to(...)
            yield
          end
        end
    end

    def sign_up_pending_actor = actor_value

    def sign_up_missing_requirements = missing_requirements_value || []

    def sign_up_handoff_pt = handoff_pt_value

    def sign_in_sequence_redirect_path(*) = "/sign-in-sequence"

    def redirect_to_sign_in_sequence!(**)
      redirect_to("/sign-in-sequence")
    end

    def path_from_signed_pt(value) = value.to_s.start_with?("signed:") ? value.delete_prefix("signed:") : nil

    def signed_pt_param = nil

    def signed_pt_token(value)
      safe = path_from_signed_pt(value)
      safe ? "signed:#{safe}" : nil
    end

    def auth_app_sign_up_path(**) = "/auth/app/sign/up"

    def auth_com_sign_up_path(**) = "/auth/com/sign/up"

    def auth_app_sign_in_path(**) = "/auth/app/sign/in"

    def auth_com_sign_in_path(**) = "/auth/com/sign/in"

    def base_app_identity_secrets_url(**) = "http://app.example/secrets"

    def base_com_identity_secrets_url(**) = "http://com.example/secrets"

    def base_authority_host = "app.example"

    def t(key, **)
      key.to_s
    end
  end

  Result =
    Struct.new(:status, :success, :next_event, :errors, :message, :redirect_to, :response_status) do
      def success?
        success
      end
    end

  test "load_sign_up_checkpoint_ticket redirects when age restricted and missing ticket" do
    harness = Harness.new
    harness.sign_up_session_state_value = SessionState.new(age_restricted: true)

    harness.send(:load_sign_up_checkpoint_ticket)

    assert_match "age_restricted", harness.rendered.first.first
    assert_equal :ok, harness.rendered.last[:status]

    state2 = SessionState.new(age_restricted: false)
    harness.sign_up_session_state_value = state2
    harness.send(:load_sign_up_checkpoint_ticket)

    assert_equal "/auth/app/sign/up", harness.redirected.first.first
    assert state2.cleared

    harness.redirected = nil
    harness.ticket = Struct.new(:public_id, :checkpoint_version).new("t-1", 1)
    harness.locator_current = harness.ticket

    harness.send(:load_sign_up_checkpoint_ticket)

    assert_equal harness.ticket, harness.instance_variable_get(:@sign_up_ticket)
    assert_nil harness.redirected
  end

  test "authorize helpers reject when context is missing or policy denies" do
    harness = Harness.new
    harness.allowed_value = false

    harness.send(:authorize_sign_up_participant!, :show?)

    assert_equal :forbidden, harness.rendered.last[:status]

    # No `requirement` param, so sign_up_requirement_context resolves to nil.
    harness.rendered = nil
    harness.send(:authorize_sign_up_requirement!, :show?)

    assert_equal :forbidden, harness.rendered.last[:status]

    # Context resolves, but the policy denies both the rule and the cleared-continue rule.
    harness.rendered = nil
    harness.params_hash = { requirement: "birthdate" }

    SignUpRequirementContext.stub(:build, Object.new) do
      harness.send(:authorize_sign_up_requirement_or_cleared_continue!, :show?)
    end

    assert_equal :forbidden, harness.rendered.last[:status]
  end

  test "sign_up_policy_context builds with the current ticket" do
    harness = Harness.new
    ticket = Struct.new(:public_id).new("t-1")
    harness.ticket = ticket
    harness.instance_variable_set(:@sign_up_ticket, ticket)

    built = nil
    SignUpPolicyContext.stub(:build, ->(**kwargs) { built = kwargs; Struct.new(:pending_actor).new(nil) }) do
      harness.send(:sign_up_policy_context)
    end

    assert_equal :app, built[:surface]
    assert_equal ticket, built[:ticket]
  end

  test "run_sign_up_event renders result when not already performed" do
    harness = Harness.new

    # No ticket is loaded, so the state machine rejects the event and
    # render_sign_up_result maps the unknown status to 422.
    harness.send(:run_sign_up_event, :some_event)

    assert_equal "invalid_transition", harness.rendered.last[:plain]
    assert_equal :unprocessable_content, harness.rendered.last[:status]

    harness.rendered = nil
    harness.performed_value = true

    harness.send(:run_sign_up_event, :some_event)

    assert_nil harness.rendered
  end

  test "run_sign_up_requirement_event finalizes or renders based on result" do
    harness = Harness.new
    finalized = false
    harness.define_singleton_method(:sign_up_checkpoint_version_param) { "1" }
    harness.define_singleton_method(:perform_sign_up_event) do |_event, **_|
      Result.new(:ok, true, :finalize, [], nil, nil, nil)
    end
    harness.define_singleton_method(:finalize_sign_up_from_checkpoint!) { finalized = true }

    harness.send(:run_sign_up_requirement_event)

    assert finalized

    finalized = false
    harness.define_singleton_method(:perform_sign_up_event) do |_event, **_|
      Result.new(:blocked, false, nil, [], nil, nil, nil)
    end

    harness.send(:run_sign_up_requirement_event)

    assert_equal :forbidden, harness.rendered.last[:status]
    assert_equal "blocked", harness.rendered.last[:plain]
  end

  test "enter_sign_up_checkpoint! renders checkpoint or finalizes" do
    harness = Harness.new
    ticket = Struct.new(:sign_up_checkpoint_pending?).new(false)
    harness.instance_variable_set(:@sign_up_ticket, ticket)
    harness.define_singleton_method(:sign_up_missing_requirements) { ["email"] }
    harness.define_singleton_method(:render_sign_up_checkpoint) { render :show, status: :ok }
    harness.define_singleton_method(:perform_sign_up_event) do |_event, **_|
      Result.new(:ok, true, nil, [], nil, nil, nil)
    end

    harness.send(:enter_sign_up_checkpoint!)

    assert_equal [:show], harness.rendered.first

    harness.rendered = nil
    harness.define_singleton_method(:sign_up_missing_requirements) { [] }
    finalized = false
    harness.define_singleton_method(:finalize_sign_up_from_checkpoint!) { finalized = true }

    harness.send(:enter_sign_up_checkpoint!)

    assert finalized

    harness.instance_variable_set(:@sign_up_ticket, Struct.new(:sign_up_checkpoint_pending?).new(true))
    harness.rendered = nil
    finalized = false

    harness.send(:enter_sign_up_checkpoint!)

    assert finalized
    assert_nil harness.rendered
  end

  test "persist_sign_up_birthdate_requirement covers all branches" do
    harness = Harness.new

    harness.define_singleton_method(:sign_up_requirement_param) { "email" }

    assert harness.send(:persist_sign_up_birthdate_requirement)

    harness.define_singleton_method(:sign_up_requirement_param) { "birthdate" }
    harness.define_singleton_method(:validate_sign_up_checkpoint_version!) { false }

    assert_not harness.send(:persist_sign_up_birthdate_requirement)

    harness.define_singleton_method(:validate_sign_up_checkpoint_version!) { true }
    harness.actor_value = nil

    harness.send(:persist_sign_up_birthdate_requirement)

    assert_equal :not_found, harness.rendered.last[:status]

    actor = Struct.new(:birthdate, :errors, :save).new(nil, Struct.new(:full_messages).new(["bad"]), false)
    harness.actor_value = actor
    harness.define_singleton_method(:sign_up_birthdate_param) { "2000-01-01" }

    harness.send(:persist_sign_up_birthdate_requirement)

    assert_match "bad", harness.rendered.last[:plain]
    assert_equal :unprocessable_content, harness.rendered.last[:status]

    actor = Struct.new(:birthdate, :errors, :save).new(nil, Struct.new(:full_messages).new([]), true)
    harness.actor_value = actor
    harness.rendered = nil

    assert harness.send(:persist_sign_up_birthdate_requirement)
    assert_equal "2000-01-01", actor.birthdate
  end

  test "clear_sign_up_birthdate_requirement covers age restriction and cleared branches" do
    harness = Harness.new
    harness.define_singleton_method(:sign_up_requirement_cleared?) { |*| true }
    harness.define_singleton_method(:sign_up_missing_requirements) { [] }
    finalized = false
    harness.define_singleton_method(:finalize_sign_up_from_checkpoint!) { finalized = true }

    harness.send(:clear_sign_up_birthdate_requirement)

    assert finalized

    harness.define_singleton_method(:sign_up_requirement_cleared?) { |*| false }
    harness.define_singleton_method(:validate_sign_up_checkpoint_version!) { false }
    harness.send(:clear_sign_up_birthdate_requirement)

    assert_nil harness.rendered

    harness.define_singleton_method(:validate_sign_up_checkpoint_version!) { true }
    harness.actor_value = nil
    harness.send(:clear_sign_up_birthdate_requirement)

    assert_equal :not_found, harness.rendered.last[:status]

    actor = Struct.new(:birthdate, :errors, :save).new(nil, Struct.new(:full_messages).new(["bad"]), false)
    harness.actor_value = actor
    harness.define_singleton_method(:sign_up_birthdate_param) { "2000-01-01" }
    harness.send(:clear_sign_up_birthdate_requirement)

    assert_match "bad", harness.rendered.last[:plain]

    actor = Struct.new(:birthdate, :errors, :save).new(nil, Struct.new(:full_messages).new([]), true)
    harness.actor_value = actor
    harness.rendered = nil
    harness.define_singleton_method(:sign_up_requirement_param) { "birthdate" }
    SignUpEligibilityPolicy.stub(:minimum_age_reached?, false) do
      terminated = Result.new(:ok, true, nil, [], nil, nil, nil)
      SignUpTermination.stub(:call, terminated) do
        harness.send(:clear_sign_up_birthdate_requirement)
      end
    end

    assert_match "age_restricted", harness.rendered.first.first

    harness.rendered = nil
    SignUpEligibilityPolicy.stub(:minimum_age_reached?, true) do
      harness.define_singleton_method(:perform_sign_up_event) do |_event, **_|
        Result.new(:ok, true, nil, [], nil, nil, nil)
      end
      harness.send(:clear_sign_up_birthdate_requirement)
    end

    assert_equal "ok", harness.rendered.last[:plain]
  end

  test "validate_sign_up_checkpoint_version! renders plain stale checkpoint on invalid input" do
    harness = Harness.new
    ticket = Struct.new(:checkpoint_version, :has_attribute?).new(7, true)
    harness.instance_variable_set(:@sign_up_ticket, ticket)
    harness.define_singleton_method(:sign_up_checkpoint_version_param) { "invalid" }

    assert_not harness.send(:validate_sign_up_checkpoint_version!)
    assert_equal "stale_checkpoint", harness.rendered.last[:plain]

    harness.rendered = nil

    assert_not harness.send(:validate_sign_up_checkpoint_version!, json: true)
    assert_equal({ error: "stale_checkpoint" }, harness.rendered.last[:json])
  end

  test "sign_up_telephone_edit_path falls back to default sign in path for unknown surface" do
    harness = Harness.new
    harness.surface_value = :org

    assert_equal "/", harness.send(:sign_up_telephone_edit_path)
  end

  test "finalize_app_sign_up_actor! covers branches and rescue" do
    harness = Harness.new
    harness.instance_variable_set(
      :@sign_up_ticket,
      Struct.new(:pending_contact_type, :pending_contact_id).new("other", nil),
    )
    harness.actor_value = Struct.new(:public_id).new("a-1")

    assert_equal :failed, harness.send(:finalize_app_sign_up_actor!, harness.actor_value)

    harness.instance_variable_set(
      :@sign_up_ticket,
      Struct.new(:pending_contact_type, :pending_contact_id).new("telephone", 1),
    )
    telephone = Struct.new(:id).new(1)
    ClientTelephone.stub(:find_by, telephone) do
      SignAppUpTelephoneRegistrationFinalizer.stub(:call, Struct.new(:status).new(:ok)) do
        harness.define_singleton_method(:issue_sign_up_recovery_passcodes!) { |*| nil }

        assert_equal :accepted, harness.send(:finalize_app_sign_up_actor!, harness.actor_value)
      end
      # The telephone branch signals failure by raising, not by its return value,
      # so a nil finalizer result still completes the sign-up.
      SignAppUpTelephoneRegistrationFinalizer.stub(:call, nil) do
        harness.define_singleton_method(:issue_sign_up_recovery_passcodes!) { |*| nil }

        assert_equal :accepted, harness.send(:finalize_app_sign_up_actor!, harness.actor_value)
      end
      SignAppUpTelephoneRegistrationFinalizer.stub(
        :call, ->(*) {
                 raise SignAppUpTelephoneRegistrationFinalizer::PasskeyMissingError
               },
      ) do
        harness.define_singleton_method(:issue_sign_up_recovery_passcodes!) { |*| nil }

        assert_equal :failed, harness.send(:finalize_app_sign_up_actor!, harness.actor_value)
      end
    end

    actor = Struct.new(:status_id, :public_id) do
      def update!(attributes)
        attributes.each { |name, value| public_send(:"#{name}=", value) }
        true
      end
    end.new(ClientStatus::UNVERIFIED_WITH_SIGN_UP, "a-1")
    harness.actor_value = actor
    harness.instance_variable_set(
      :@sign_up_ticket,
      Struct.new(:pending_contact_type, :pending_contact_id).new("email", nil),
    )
    Client.stub(:transaction, ->(&block) { block.call }) do
      harness.define_singleton_method(:issue_sign_up_recovery_passcodes!) { |*| nil }

      assert_equal :accepted, harness.send(:finalize_app_sign_up_actor!, actor)
      assert_equal ClientStatus::VERIFIED_WITH_SIGN_UP, actor.status_id
    end
  end

  test "finalize_com_sign_up_actor! covers branches and rescue" do
    harness = Harness.new
    harness.instance_variable_set(
      :@sign_up_ticket,
      Struct.new(:pending_contact_type, :pending_contact_id).new("other", nil),
    )

    assert_equal :failed, harness.send(:finalize_com_sign_up_actor!, Struct.new(:public_id).new("a-1"))

    harness.instance_variable_set(
      :@sign_up_ticket,
      Struct.new(:pending_contact_type, :pending_contact_id).new("telephone", 1),
    )
    telephone = Struct.new(:id).new(1)
    VisitorTelephone.stub(:find_by, telephone) do
      SignComUpTelephoneRegistrationFinalizer.stub(:call, Struct.new(:status).new(:ok)) do
        harness.define_singleton_method(:issue_sign_up_recovery_passcodes!) { |*| nil }

        assert_equal :accepted, harness.send(:finalize_com_sign_up_actor!, Struct.new(:public_id).new("a-1"))
      end
      # As on app, the com telephone branch ignores the finalizer's return value.
      SignComUpTelephoneRegistrationFinalizer.stub(:call, nil) do
        harness.define_singleton_method(:issue_sign_up_recovery_passcodes!) { |*| nil }

        assert_equal :accepted, harness.send(:finalize_com_sign_up_actor!, Struct.new(:public_id).new("a-1"))
      end
    end

    harness.instance_variable_set(
      :@sign_up_ticket,
      Struct.new(:pending_contact_type, :pending_contact_id).new("email", nil),
    )
    harness.define_singleton_method(:issue_sign_up_recovery_passcodes!) { |*| nil }

    assert_equal :accepted, harness.send(:finalize_com_sign_up_actor!, Struct.new(:public_id).new("a-1"))
  end

  test "sign_up_handoff_redirect_url covers success mfa and failure branches" do
    harness = Harness.new
    harness.handoff_pt_value = "/after"
    success = Struct.new(:success?, :mfa_required?, :session_limit_pending?, :redirect_to).new(true, false, false, nil)

    assert_equal "/sign-in-sequence", harness.send(:sign_up_handoff_redirect_url, success)

    mfa = Struct.new(:success?, :mfa_required?, :session_limit_pending?, :redirect_to).new(false, true, false, "/mfa")

    assert_equal "/mfa", harness.send(:sign_up_handoff_redirect_url, mfa)

    failed = Struct.new(:success?, :mfa_required?, :session_limit_pending?, :redirect_to).new(false, false, false, nil)

    assert_equal "/auth/app/sign/in", harness.send(:sign_up_handoff_redirect_url, failed)
  end

  test "sign_up_default_sign_in_path and restart_path fall back for unknown surface" do
    harness = Harness.new
    harness.surface_value = :org

    assert_equal "/", harness.send(:sign_up_default_sign_in_path)
    assert_equal "/", harness.send(:sign_up_restart_path)
  end

  test "finalize_sign_up_from_checkpoint! handles invalid transition" do
    harness = Harness.new
    ticket = Struct.new(:public_id, :sign_up_checkpoint_pending?, :step) do
      def reload
        self
      end

      def with_cycle_lock
        yield
      end
    end.new("t-1", false, :checkpoint)
    harness.instance_variable_set(:@sign_up_ticket, ticket)
    harness.define_singleton_method(:sign_up_finalization_context) { Struct.new(:pending_actor).new(nil) }
    harness.define_singleton_method(:allowed_to?) { |*, **| true }
    harness.define_singleton_method(:sign_up_ticket_record_class) do
      Class.new do
        def self.connected_to(...)
          yield
        end
      end
    end

    harness.send(:finalize_sign_up_from_checkpoint!)

    assert_equal :unprocessable_content, harness.rendered.last[:status]
    assert_equal "invalid_transition", harness.rendered.last[:plain]
  end

  test "sign_up_pending_actor_model and telephone_model return nil for unknown ticket" do
    harness = Harness.new
    harness.instance_variable_set(:@sign_up_ticket, Object.new)

    assert_nil harness.send(:sign_up_pending_actor_model)
    assert_nil harness.send(:sign_up_pending_telephone_model)
  end

  test "issue_sign_up_recovery_passcodes! handles empty top up and unsupported surface" do
    harness = Harness.new
    actor = Struct.new(:public_id).new("a-1")

    RecoveryPasscodeTopUp.stub(:call, Struct.new(:raw_values, :issued_count).new([], 0)) do
      assert_nil harness.send(:issue_sign_up_recovery_passcodes!, surface: :app, actor: actor)
    end

    assert_raises(ArgumentError) do
      harness.send(:sign_up_recovery_passcode_config, :other)
    end
  end

  test "sign_up_actor_authentication builds from Actor authn" do
    harness = Harness.new
    authn = Struct.new(:login_public_id, :access_claims, :acr, :amr, :actor_type, :actor_id, :restricted?).new(
      "login-1", { "sid" => "s1" }, "aal1", ["email"], :client, 42, false,
    )
    ticket = Struct.new(:public_id).new("t-1")
    harness.instance_variable_set(:@sign_up_ticket, ticket)

    Actor.stub(:authn, authn) do
      result = harness.send(:sign_up_actor_authentication)

      assert_equal "login-1", result.login_public_id
      assert_equal "t-1", result.active_sign_sequence_id
    end
  end
end

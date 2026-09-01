# typed: false
# frozen_string_literal: true

require "test_helper"

# Clearing the birthdate requirement of a social sign-up is the last gate before
# the account is committed. An applicant below the minimum age must have the
# cycle failed rather than the requirement cleared, a confirmation that was
# never given must stop the step, and a provider-side failure must answer as an
# unprocessable submission instead of escaping as a 500.
class SignUpSocialBirthdateSupportGuardsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class SessionState
    attr_accessor :age_restricted
  end

  class Harness
    include SignUpSocialBirthdateSupport

    attr_accessor :birthdate, :confirmation_cleared, :renders, :age_restricted_rendered,
                  :requirement_cleared, :candidate_error, :session_state

    def initialize
      @renders = []
      @session_state = SessionState.new
      @confirmation_cleared = true
      @requirement_cleared = false
    end

    def pending_social_signup_confirmation?
      return true unless instance_variable_defined?(:@sign_up_ticket)

      super
    end

    def performed? = false

    def sign_up_requirement_cleared?(_requirement) = requirement_cleared

    def validate_sign_up_checkpoint_version! = true

    def social_signup_confirmation_cleared? = confirmation_cleared

    def sign_up_birthdate_param = birthdate

    def sign_up_session_state = session_state

    def sign_up_checkpoint_version_param = 1

    def render_sign_up_age_restricted
      self.age_restricted_rendered = true
    end

    def render_sign_up_result(result)
      renders << [:result, result]
    end

    def render(*args, **kwargs)
      renders << [:render, args, kwargs]
    end

    def social_signup_candidate!
      raise candidate_error if candidate_error

      :candidate
    end

    def render_social_signup_completion!(candidate, birthdate)
      renders << [:completion, candidate, birthdate]
    end

    def perform_sign_up_event(*, **)
      Struct.new(:success?, :status, :next_event).new(true, :ok, :finalize)
    end

    def invoke(name, ...) = send(name, ...)
  end

  class SocialSignupTicketStub
    attr_accessor :principal_id

    def initialize(principal_id:)
      @principal_id = principal_id
    end

    def social_entry_method? = true

    def completed_requirements
      { "social_signup" => { "candidate_ref" => "ref" } }
    end
  end

  setup do
    @harness = Harness.new
  end

  test "an applicant below the minimum age has the cycle failed and sees the age-restricted page" do
    @harness.birthdate = Time.zone.today

    SignUpTermination.stub(:call, Struct.new(:success?, :status).new(true, :failed)) do
      @harness.invoke(:clear_sign_up_birthdate_requirement)
    end

    assert @harness.session_state.age_restricted
    assert @harness.age_restricted_rendered
    assert_empty @harness.renders
  end

  test "a cycle that refuses to fail is reported through the sign-up result instead" do
    @harness.birthdate = Time.zone.today
    refused = Struct.new(:success?, :status).new(false, :conflict)

    SignUpTermination.stub(:call, refused) do
      @harness.invoke(:clear_sign_up_birthdate_requirement)
    end

    assert_equal [[:result, refused]], @harness.renders
    assert_nil @harness.age_restricted_rendered
  end

  test "a sign-up whose confirmation was never given is stopped before the birthdate is read" do
    @harness.confirmation_cleared = false

    @harness.invoke(:clear_sign_up_birthdate_requirement)

    assert_equal [[:render, [], { plain: "social_signup_confirmation_required",
                                  status: :unprocessable_content, },]],
                 @harness.renders
  end

  test "a provider-side failure answers as an unprocessable submission rather than escaping" do
    @harness.birthdate = 30.years.ago.to_date
    @harness.candidate_error = SocialAuth::ProviderError.new("errors.social_auth.provider_error")

    @harness.invoke(:clear_sign_up_birthdate_requirement)

    assert_equal [[:render, [], { plain: I18n.t("errors.social_auth.provider_error"),
                                  status: :unprocessable_content, },]],
                 @harness.renders
  end

  test "an eligible applicant whose checkpoint event finalizes completes social signup" do
    @harness.birthdate = 30.years.ago.to_date

    @harness.invoke(:clear_sign_up_birthdate_requirement)

    assert_equal [[:completion, :candidate, @harness.birthdate]], @harness.renders
  end

  test "an eligible applicant whose checkpoint event does not finalize is shown the result" do
    @harness.birthdate = 30.years.ago.to_date
    @harness.define_singleton_method(:perform_sign_up_event) do |*|
      Struct.new(:success?, :status, :next_event).new(true, :ok, :advance)
    end

    @harness.invoke(:clear_sign_up_birthdate_requirement)

    assert_equal :advance, @harness.renders.first.last.next_event
  end

  test "a failed checkpoint event is shown as a result rather than completing" do
    @harness.birthdate = 30.years.ago.to_date
    failed = Struct.new(:success?, :status, :next_event).new(false, :blocked, nil)
    @harness.define_singleton_method(:perform_sign_up_event) { |*| failed }

    @harness.invoke(:clear_sign_up_birthdate_requirement)

    assert_equal [[:result, failed]], @harness.renders
  end

  test "a request that already ran or already cleared birthdate does not re-enter the gate" do
    @harness.define_singleton_method(:performed?) { true }
    @harness.invoke(:clear_sign_up_birthdate_requirement)

    assert_empty @harness.renders

    @harness = Harness.new
    @harness.requirement_cleared = true
    @harness.invoke(:clear_sign_up_birthdate_requirement)

    assert_equal [[:completion, :candidate, nil]], @harness.renders
  end

  test "a request that is not a pending social signup defers to the parent implementation" do
    parent =
      Class.new do
        def clear_sign_up_birthdate_requirement = :parent
      end
    child =
      Class.new(parent) do
        include SignUpSocialBirthdateSupport

        def pending_social_signup_confirmation? = false
      end

    assert_equal :parent, child.new.send(:clear_sign_up_birthdate_requirement)
  end

  test "pending social signup confirmation requires a social ticket without a principal and with evidence" do
    ticket = SocialSignupTicketStub.new(principal_id: nil)
    @harness.instance_variable_set(:@sign_up_ticket, ticket)

    assert @harness.send(:pending_social_signup_confirmation?)

    ticket.principal_id = "already-committed"

    assert_not @harness.send(:pending_social_signup_confirmation?)
  end

  test "social signup evidence is ignored unless it is a hash" do
    ticket = Object.new
    ticket.define_singleton_method(:completed_requirements) { { "social_signup" => "not-a-hash" } }
    @harness.instance_variable_set(:@sign_up_ticket, ticket)

    assert_nil @harness.send(:social_signup_evidence)
  end

  test "validate_social_signup_candidate! refuses every binding mismatch" do
    ticket = Struct.new(:public_id, :social_provider).new("ticket-1", "google")
    @harness.instance_variable_set(:@sign_up_ticket, ticket)
    evidence = {
      "candidate_digest" => "digest-1",
      "grant_transaction_id" => "txn-1",
      "provider" => "google",
      "uid_digest" => "wrong",
    }
    @harness.define_singleton_method(:social_signup_evidence) { evidence }
    candidate = Struct.new(
      :digest, :surface, :actor_ref, :session_ref, :transaction_id, :operation, :provider, :callback_result,
    ).new(
      "digest-1", "app", "ticket-1", "ticket-1", "txn-1", "signup", "google",
      Struct.new(:principal).new(Struct.new(:subject).new("uid")),
    )

    error =
      assert_raises(IdentitySocialCeremonyContract::Error) do
        @harness.send(:validate_social_signup_candidate!, candidate)
      end
    assert_includes error.message, "candidate uid mismatch"

    candidate.digest = "other"
    error =
      assert_raises(IdentitySocialCeremonyContract::Error) do
        @harness.send(:validate_social_signup_candidate!, candidate)
      end
    assert_includes error.message, "candidate digest mismatch"
  end

  test "social signup ceremony grant refuses a missing transaction id" do
    @harness.define_singleton_method(:social_signup_evidence) { {} }

    error =
      assert_raises(IdentitySocialCeremonyContract::Error) do
        @harness.send(:social_signup_ceremony_grant)
      end
    assert_includes error.message, "social signup grant is required"
  end
end

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

    def pending_social_signup_confirmation? = true

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
                                  status: :unprocessable_content, }]],
                 @harness.renders
  end

  test "a provider-side failure answers as an unprocessable submission rather than escaping" do
    @harness.birthdate = 30.years.ago.to_date
    @harness.candidate_error = SocialAuth::ProviderError.new("errors.social_auth.provider_error")

    @harness.invoke(:clear_sign_up_birthdate_requirement)

    assert_equal [[:render, [], { plain: I18n.t("errors.social_auth.provider_error"),
                                  status: :unprocessable_content, }]],
                 @harness.renders
  end
end

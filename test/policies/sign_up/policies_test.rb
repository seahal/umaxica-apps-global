# typed: false
# frozen_string_literal: true

require "test_helper"

class SignUpPoliciesTest < ActiveSupport::TestCase
  AuthFacts =
    Data.define(:signed_in, :active_sign_sequence_id) do
      def signed_in?
        signed_in
      end
    end

  PendingActor = Data.define(:id)

  test "ticket policy rejects signed-in actors from starting sign-up" do
    context = SignUp::PolicyContext.build(
      surface: :app,
      actor_authentication: auth(signed_in: true),
      ticket: nil,
    )

    assert_not_predicate SignUp::TicketPolicy.new(context, user: nil), :start?
  end

  test "ticket policy allows anonymous start" do
    context = SignUp::PolicyContext.build(
      surface: :app,
      actor_authentication: auth(signed_in: false),
      ticket: nil,
    )

    assert_predicate SignUp::TicketPolicy.new(context, user: nil), :start?
  end

  test "ticket policy requires sequence binding for existing tickets" do
    ticket = build_ticket(ClientSignUpCycle, entry_method: "email", step: "start")
    bound_context = policy_context(ticket, auth: auth(active_sign_sequence_id: ticket.public_id))
    unbound_context = policy_context(ticket, auth: auth(active_sign_sequence_id: "wrong-sequence"))

    assert_predicate SignUp::TicketPolicy.new(bound_context, user: nil), :submit_contact?
    assert_not_predicate SignUp::TicketPolicy.new(unbound_context, user: nil), :submit_contact?
  end

  test "ticket policy rejects signed-in actor from resuming sign-up" do
    ticket = build_ticket(ClientSignUpCycle, entry_method: "email", step: "start")
    context = policy_context(ticket, auth: auth(signed_in: true, active_sign_sequence_id: ticket.public_id))

    assert_not_predicate SignUp::TicketPolicy.new(context, user: Object.new), :resume?
  end

  test "ticket policy rejects binding to another ticket public id" do
    ticket = build_ticket(ClientSignUpCycle, entry_method: "email", step: "start")
    other_ticket = build_ticket(ClientSignUpCycle, entry_method: "email", step: "start")
    context = policy_context(ticket, auth: auth(active_sign_sequence_id: other_ticket.public_id))

    assert_not_predicate SignUp::TicketPolicy.new(context, user: nil), :show?
    assert_not_predicate SignUp::TicketPolicy.new(context, user: nil), :submit_contact?
  end

  test "ticket policy rejects terminal and expired tickets" do
    completed = build_ticket(
      ClientSignUpCycle,
      status_id: ClientSignUpCycleStatus::COMPLETED,
      step: "completed",
      completed_at: Time.current,
    )
    expired = build_ticket(ClientSignUpCycle, issued_at: 2.minutes.ago, expires_at: 1.minute.ago)

    assert_not_predicate SignUp::TicketPolicy.new(policy_context(completed), user: nil), :show?
    assert_not_predicate SignUp::TicketPolicy.new(policy_context(expired), user: nil), :show?
  end

  test "ticket policy rejects cross-surface context" do
    ticket = build_ticket(ClientSignUpCycle, entry_method: "email")
    context = SignUp::PolicyContext.build(
      surface: :com,
      actor_authentication: auth(active_sign_sequence_id: ticket.public_id),
      ticket: ticket,
    )

    assert_not_predicate SignUp::TicketPolicy.new(context, user: nil), :show?
  end

  test "participant policy allows checkpoint only from sign-up participant states" do
    contact_verified = build_ticket(
      ClientSignUpCycle, status_id: ClientSignUpCycleStatus::CONTACT_VERIFIED,
                         step: "contact_verified",
    )
    contact_pending = build_ticket(
      ClientSignUpCycle, status_id: ClientSignUpCycleStatus::CONTACT_PENDING,
                         step: "contact",
    )

    assert_predicate SignUp::ParticipantPolicy.new(policy_context(contact_verified), user: nil), :enter_checkpoint?
    assert_not_predicate SignUp::ParticipantPolicy.new(policy_context(contact_pending), user: nil), :enter_checkpoint?
  end

  test "requirement policy allows only ticket-owned checkpoint requirements" do
    ticket = build_ticket(
      ClientSignUpCycle,
      entry_method: "telephone",
      status_id: ClientSignUpCycleStatus::CHECKPOINT_PENDING,
      step: "checkpoint",
      principal_id: 42,
    )
    context = requirement_context(ticket, requirement: :passkey, pending_actor: PendingActor.new(id: 42))

    policy = SignUp::RequirementPolicy.new(context, user: nil)

    assert_predicate policy, :clear_requirement?
    assert_predicate policy, :register_passkey?
    assert_not_predicate policy, :confirm_passcode?
  end

  test "requirement policy rejects wrong pending actor" do
    ticket = build_ticket(
      ClientSignUpCycle,
      entry_method: "telephone",
      status_id: ClientSignUpCycleStatus::CHECKPOINT_PENDING,
      step: "checkpoint",
      principal_id: 42,
    )
    context = requirement_context(ticket, requirement: :passkey, pending_actor: PendingActor.new(id: 99))

    assert_not_predicate SignUp::RequirementPolicy.new(context, user: nil), :clear_requirement?
  end

  test "finalization policy requires all requirements clear" do
    ticket = build_ticket(
      ClientSignUpCycle,
      entry_method: "telephone",
      status_id: ClientSignUpCycleStatus::CHECKPOINT_PENDING,
      step: "checkpoint",
      principal_id: 42,
      completed_requirements: {
        "birthdate" => { "cleared" => true },
        "passkey" => { "cleared" => true },
        "passcode" => { "cleared" => true },
      },
    )
    context = SignUp::FinalizationContext.build(
      surface: :app,
      actor_authentication: auth(active_sign_sequence_id: ticket.public_id),
      ticket: ticket,
      pending_actor: PendingActor.new(id: 42),
    )

    assert_predicate SignUp::FinalizationPolicy.new(context, user: nil), :finalize?
  end

  test "finalization context rejects missing telephone requirements before policy evaluation" do
    ticket = build_ticket(
      ClientSignUpCycle,
      entry_method: "telephone",
      status_id: ClientSignUpCycleStatus::CHECKPOINT_PENDING,
      step: "checkpoint",
      principal_id: 42,
      completed_requirements: {
        "birthdate" => { "cleared" => true },
        "passkey" => { "cleared" => true },
      },
    )

    assert_raises(ArgumentError) do
      SignUp::FinalizationContext.build(
        surface: :app,
        actor_authentication: auth(active_sign_sequence_id: ticket.public_id),
        ticket: ticket,
        pending_actor: PendingActor.new(id: 42),
      )
    end
  end

  test "social callback policy is app social only" do
    app_ticket = build_ticket(
      ClientSignUpCycle,
      entry_method: "google",
      status_id: ClientSignUpCycleStatus::STARTED,
      step: "start",
    )
    com_ticket = build_ticket(
      VisitorSignUpCycle,
      entry_method: "email",
      status_id: VisitorSignUpCycleStatus::STARTED,
      step: "start",
    )

    assert_predicate SignUp::SocialCallbackPolicy.new(policy_context(app_ticket), user: nil), :start_social_callback?
    assert_not_predicate SignUp::SocialCallbackPolicy.new(policy_context(com_ticket), user: nil),
                         :start_social_callback?
  end

  test "social callback policy requires the matching social step" do
    start_ticket = build_ticket(
      ClientSignUpCycle,
      entry_method: "google",
      status_id: ClientSignUpCycleStatus::STARTED,
      step: "start",
    )
    callback_ticket = build_ticket(
      ClientSignUpCycle,
      entry_method: "google",
      status_id: ClientSignUpCycleStatus::SOCIAL_CALLBACK_PENDING,
      step: "social_callback",
    )

    assert_predicate SignUp::SocialCallbackPolicy.new(policy_context(start_ticket), user: nil), :start_social_callback?
    assert_not_predicate SignUp::SocialCallbackPolicy.new(policy_context(start_ticket), user: nil),
                         :complete_social_callback?
    assert_not_predicate SignUp::SocialCallbackPolicy.new(policy_context(callback_ticket), user: nil),
                         :start_social_callback?
    assert_predicate SignUp::SocialCallbackPolicy.new(policy_context(callback_ticket), user: nil),
                     :complete_social_callback?
  end

  private

  def auth(signed_in: false, active_sign_sequence_id: nil)
    AuthFacts.new(signed_in: signed_in, active_sign_sequence_id: active_sign_sequence_id)
  end

  def policy_context(ticket, auth: auth(active_sign_sequence_id: ticket.public_id))
    SignUp::PolicyContext.build(
      surface: SignUp::RequirementRegistry.surface_for_ticket(ticket),
      actor_authentication: auth,
      ticket: ticket,
    )
  end

  def requirement_context(ticket, requirement:, pending_actor:)
    SignUp::RequirementContext.build(
      surface: SignUp::RequirementRegistry.surface_for_ticket(ticket),
      actor_authentication: auth(active_sign_sequence_id: ticket.public_id),
      ticket: ticket,
      requirement: requirement,
      pending_actor: pending_actor,
    )
  end

  def build_ticket(cycle_class, attrs = {})
    ticket = cycle_class.new(cycle_attrs(cycle_class).merge(attrs))

    assert_predicate ticket, :valid?, ticket.errors.full_messages.join(", ")
    ticket
  end

  def cycle_attrs(cycle_class)
    {
      principal_id: nil,
      status_id: cycle_class::STATUS_IDS.first,
      step: cycle_class::STEPS.first,
      nonce_digest: cycle_class.digest_nonce("nonce"),
      issued_at: Time.current,
      expires_at: 15.minutes.from_now,
      entry_method: "email",
    }
  end
end

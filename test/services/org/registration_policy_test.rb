# typed: false
# frozen_string_literal: true

require "test_helper"

class Org::RegistrationPolicyTest < ActiveSupport::TestCase
  setup do
    Prosopite.pause do
      [0, 1, 2, 3].each { |id| OrganizationStatus.find_or_create_by!(id: id) }
    end
    @staff = Operator.create!(status_id: OperatorStatus::ACTIVE)
    @organization = Organization.create!(name: "Test Org")
    @invitation = OrganizationInvitation.create!(
      organization_id: @organization.id,
      email: "invitee@example.com",
      invited_by: @staff,
    )
  end

  test "allowed? returns true for valid code" do
    policy = Org::RegistrationPolicy.new(invitation_code: @invitation.code)

    assert_predicate policy, :allowed?
  end

  test "allowed? returns false for blank code" do
    assert_not Org::RegistrationPolicy.allowed?(invitation_code: nil)
    assert_not Org::RegistrationPolicy.allowed?(invitation_code: "")
  end

  test "allowed? returns false for invalid code" do
    assert_not Org::RegistrationPolicy.allowed?(invitation_code: "invalid")
  end

  test "validate! returns invitation for valid code" do
    result = Org::RegistrationPolicy.validate!(invitation_code: @invitation.code)

    assert_equal @invitation, result
  end

  test "validate! raises InvitationRequiredError for blank code" do
    assert_raises(Org::RegistrationPolicy::InvitationRequiredError) do
      Org::RegistrationPolicy.validate!(invitation_code: "")
    end
  end

  test "validate! raises InvalidInvitationError for unknown code" do
    assert_raises(Org::RegistrationPolicy::InvalidInvitationError) do
      Org::RegistrationPolicy.validate!(invitation_code: "unknown")
    end
  end

  test "validate! raises InvitationConsumedError for used code" do
    @invitation.update!(consumed_at: Time.current)

    assert_raises(Org::RegistrationPolicy::InvitationConsumedError) do
      Org::RegistrationPolicy.validate!(invitation_code: @invitation.code)
    end
  end

  test "validate! raises InvitationExpiredError for expired code" do
    @invitation.update!(expires_at: 1.day.ago)

    assert_raises(Org::RegistrationPolicy::InvitationExpiredError) do
      Org::RegistrationPolicy.validate!(invitation_code: @invitation.code)
    end
  end

  test "consume! consumes the invitation" do
    policy = Org::RegistrationPolicy.new(invitation_code: @invitation.code)
    result = policy.consume!

    assert_equal @invitation, result
    assert_predicate result.reload, :consumed?
  end

  test "consume! raises error if already consumed" do
    @invitation.update!(consumed_at: Time.current)
    policy = Org::RegistrationPolicy.new(invitation_code: @invitation.code)

    assert_raises(Org::RegistrationPolicy::InvitationConsumedError) do
      policy.consume!
    end
  end
end

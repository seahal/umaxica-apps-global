# typed: false
# frozen_string_literal: true

require "test_helper"

class OrgOperatorLifecycleInvitationAcceptanceTest < ActiveSupport::TestCase
  fixtures :operators, :operator_statuses, :operator_email_statuses, :operator_visibilities

  setup do
    @invitation = OrganizationInvitation.create!(
      organization_id: 123,
      email: "invitee@example.com",
      invited_by: operators(:one),
      role_id: 7,
    )
  end

  test "accepts invitation by creating active operator and protected verified email" do
    assert_difference -> { Operator.count }, 1 do
      assert_difference -> { OperatorEmail.count }, 1 do
        assert_difference -> { OperatorAccount.count }, 1 do
          assert_difference -> { OperatorIdentity.count }, 1 do
            assert_difference -> { Agent.count }, 1 do
              assert_difference -> { Bureau.count }, 1 do
                assert_difference -> { BureauUnit.count }, 1 do
                  assert_difference -> { AgentMembership.count }, 1 do
                    @result = OrgOperatorLifecycleInvitationAcceptance.call(invitation_code: @invitation.code)
                  end
                end
              end
            end
          end
        end
      end
    end

    assert_predicate @result, :success?
    assert_predicate @invitation.reload, :consumed?
    assert_equal OperatorStatus::ACTIVE, @result.operator.status_id
    assert_equal OperatorVisibility::STAFF, @result.operator.visibility_id
    assert_equal "invitee@example.com", @result.email.address
    assert_equal OperatorEmailStatus::VERIFIED, @result.email.staff_email_status_id
    assert_predicate @result.email, :undeletable?
    assert_predicate @result.operator.rp_account, :present?
    assert_equal 1, OperatorIdentity.where(source_record_id: @result.operator.id).count
  end

  test "rejects consumed invitation without creating operator" do
    @invitation.update!(consumed_at: Time.current)

    assert_no_difference -> { Operator.count } do
      result = OrgOperatorLifecycleInvitationAcceptance.call(invitation_code: @invitation.code)

      assert_not result.success?
    end
  end

  test "keeps invitation active when operator email cannot be created" do
    existing = Operator.create!(
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    existing.operator_emails.create!(
      raw_address: @invitation.email,
      confirm_policy: true,
      staff_email_status_id: OperatorEmailStatus::VERIFIED,
    )

    result = OrgOperatorLifecycleInvitationAcceptance.call(invitation_code: @invitation.code)

    assert_not result.success?
    assert_not_predicate @invitation.reload, :consumed?
  end

  test "concurrent invitation acceptance consumes once and creates side effects once" do
    invitation = OrganizationInvitation.create!(
      organization_id: 456,
      email: "race-invitee-#{SecureRandom.hex(4)}@example.com",
      invited_by: operators(:one),
      role_id: 7,
    )
    side_effect_counts = {
      agents: Agent.count,
      bureaus: Bureau.count,
      bureau_units: BureauUnit.count,
      memberships: AgentMembership.count,
    }

    results = accept_invitation_concurrently(invitation.code)

    assert_equal 2, results.size
    assert_equal 1, results.count { |result| result[:success] }, results.inspect
    assert_equal 1, results.count { |result| !result[:success] }, results.inspect
    assert results.none? { |result| result[:exception].present? }, results.inspect
    assert_includes results.filter_map { |result| result[:error] }, "Invitation has already been used"

    assert_equal 1, OrganizationInvitation.where(id: invitation.id).where.not(consumed_at: nil).count
    email_scope = OperatorEmail.where(address_digest: IdentifierBlindIndex.bidx_for_email(invitation.email))

    assert_equal 1, email_scope.count
    operator_ids = email_scope.pluck(:staff_id)

    assert_equal 1, Operator.where(id: operator_ids).count
    assert_equal 1, OperatorAccount.where(staff_id: operator_ids).count
    assert_equal 1, OperatorIdentity.where(source_record_id: operator_ids).count
    assert_equal side_effect_counts[:agents] + 1, Agent.count
    assert_equal side_effect_counts[:bureaus] + 1, Bureau.count
    assert_equal side_effect_counts[:bureau_units] + 1, BureauUnit.count
    assert_equal side_effect_counts[:memberships] + 1, AgentMembership.count
  end

  test "already consumed invitation returns deterministic failure without side effects" do
    @invitation.update!(consumed_at: Time.current)

    assert_no_difference -> { Operator.count } do
      assert_no_difference -> { OperatorEmail.count } do
        result = OrgOperatorLifecycleInvitationAcceptance.call(invitation_code: @invitation.code)

        assert_not result.success?
        assert_equal "Invitation has already been used", result.error
      end
    end
  end

  test "expired invitation returns deterministic failure without side effects" do
    @invitation.update!(expires_at: 1.minute.ago)

    assert_no_difference -> { Operator.count } do
      assert_no_difference -> { OperatorEmail.count } do
        result = OrgOperatorLifecycleInvitationAcceptance.call(invitation_code: @invitation.code)

        assert_not result.success?
        assert_equal "Invitation has expired", result.error
      end
    end
  end

  private

  def accept_invitation_concurrently(code)
    ready = Queue.new
    release = Queue.new
    results = Queue.new

    threads =
      2.times.map do
        Thread.new do # rubocop:disable ThreadSafety/NewThread
          OrganizationInvitation.connection_pool.with_connection do
            ready << true
            release.pop
            result = OrgOperatorLifecycleInvitationAcceptance.call(invitation_code: code)
            results << { success: result.success?, error: result.error, exception: nil }
          rescue StandardError => e
            results << { success: false, error: e.message, exception: e.class.name }
          end
        end
      end

    2.times { ready.pop }
    2.times { release << true }
    threads.each(&:join)
    2.times.map { results.pop }
  end
end

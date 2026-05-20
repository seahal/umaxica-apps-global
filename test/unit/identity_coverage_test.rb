# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentityCoverageTest < ActiveSupport::TestCase
  setup do
    ClientStatus.find_or_create_by!(id: 1)
    ClientVisibility.find_or_create_by!(id: 1)
    @user = Client.create!(status_id: 1, visibility_id: 1)
  end

  test "login_allowed?" do
    assert_predicate @user, :login_allowed?

    # Blocked status
    @user.update!(status_id: ClientStatus::RESERVED)

    assert_not @user.login_allowed?
  end

  test "recovery_deadline and can_recover?" do
    assert_nil @user.recovery_deadline

    # We need a value that is NOT infinity for the deadline calculation
    now = Time.current
    @user.update!(withdrawn_at: now)
    @user.reload

    assert_equal @user.withdrawn_at + 31.days, @user.recovery_deadline
    assert_predicate @user, :can_recover?
  end
end

# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_email_statuses
# Database name: principal
#
#  id :bigint           not null, primary key
#

require "test_helper"

class UserEmailStatusTest < ActiveSupport::TestCase
  test "has many user_emails" do
    assert UserEmailStatus.reflect_on_association(:user_emails)
  end

  test "status constants are defined" do
    assert_equal 1, UserEmailStatus::UNVERIFIED
    assert_equal 2, UserEmailStatus::VERIFIED
    assert_equal 3, UserEmailStatus::SUSPENDED
    assert_equal 4, UserEmailStatus::DELETED
    assert_equal 5, UserEmailStatus::NOTHING
    assert_equal 6, UserEmailStatus::UNVERIFIED_WITH_SIGN_UP
    assert_equal 7, UserEmailStatus::VERIFIED_WITH_SIGN_UP
  end

  test "ensure_defaults restores missing fixed status rows" do
    UserEmailStatus.find(UserEmailStatus::DELETED).delete
    UserEmailStatus.clear_fixed_id_seed_cache!

    UserEmailStatus.ensure_defaults!

    assert UserEmailStatus.exists?(UserEmailStatus::DELETED)
  end

  test "restrict_with_error prevents deletion when emails exist" do
    status = UserEmailStatus.find(UserEmailStatus::VERIFIED)
    # Create a user identity email with this status
    user = User.find_by!(public_id: "one_id")
    UserEmail.create!(
      id: SecureRandom.uuid,
      address: "test@example.com",
      user_id: user.id,
      user_email_status_id: status.id,
    )

    assert_raises(ActiveRecord::RecordNotDestroyed) do
      status.destroy!
    end
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthSessionLimitTest < ActiveSupport::TestCase
  class SessionLimitHarness
    include Authentication::Base

    attr_accessor :session_data

    def initialize
      @session_data = {}
    end

    def session
      @session_data
    end

    def resource_type
      "user"
    end

    def resource_class
      User
    end

    def token_class
      UserToken
    end

    def audit_class
      UserChronicle
    end

    def resource_foreign_key
      :user_id
    end

    def sign_in_url_with_return(_return_to)
      "/sign/in"
    end

    def am_i_user?
      false
    end

    def am_i_staff?
      false
    end

    def am_i_owner?
      false
    end
  end

  setup do
    @harness = SessionLimitHarness.new
    @user = users(:one)
  end

  test "max_sessions_for_resource returns correct value for User" do
    result = @harness.send(:max_sessions_for_resource, @user)

    assert_equal UserToken::MAX_SESSIONS_PER_USER, result
  end

  test "max_sessions_for_resource returns correct value for Staff" do
    staff = ::Staff.first
    result = @harness.send(:max_sessions_for_resource, staff)

    assert_equal StaffToken::MAX_SESSIONS_PER_STAFF, result
  end

  test "max_sessions_for_resource returns default for unknown type" do
    result = @harness.send(:max_sessions_for_resource, Object.new)

    assert_equal 2, result
  end

  test "session_limit_state_for returns :within_limit when under max" do
    UserToken.where(user_id: @user.id).delete_all
    result = @harness.send(:session_limit_state_for, @user)

    assert_equal :within_limit, result
  end

  test "session_limit_state_for returns :issue_restricted when at max" do
    UserToken.where(user_id: @user.id).delete_all
    UserToken::MAX_SESSIONS_PER_USER.times do
      UserToken.create!(user: @user, status: "active")
    end

    result = @harness.send(:session_limit_state_for, @user)

    assert_equal :issue_restricted, result
  end

  test "session_limit_state_for returns :hard_reject when restricted exists" do
    UserToken.where(user_id: @user.id).delete_all
    UserToken::MAX_SESSIONS_PER_USER.times do
      UserToken.create!(user: @user, status: "active")
    end
    UserToken.create!(user: @user, status: "restricted")

    result = @harness.send(:session_limit_state_for, @user)

    assert_equal :hard_reject, result
  end

  test "count_active_sessions counts only active non-restricted sessions" do
    UserToken.where(user_id: @user.id).delete_all
    2.times { UserToken.create!(user: @user, status: "active") }

    result = @harness.send(:count_active_sessions, @user)

    assert_equal 2, result
  end

  test "count_active_sessions ignores rotated refresh-token ancestors" do
    UserToken.where(user_id: @user.id).delete_all

    token = UserToken.create!(user: @user, status: UserToken::STATUS_ACTIVE)
    refresh = token.rotate_refresh_token!
    Sign::RefreshTokenService.call(refresh_token: refresh)

    result = @harness.send(:count_active_sessions, @user)

    assert_equal 1, result
  end

  test "count_active_sessions ignores rotated refresh-token ancestors for staff" do
    staff = ::Staff.first
    StaffToken.where(staff_id: staff.id).delete_all

    token = StaffToken.create!(staff: staff, status: StaffToken::STATUS_ACTIVE)
    refresh = token.rotate_refresh_token!
    Sign::RefreshTokenService.call(refresh_token: refresh)

    result = @harness.send(:count_active_sessions, staff)

    assert_equal 1, result
  end

  test "restricted_session_exists? returns true when restricted session exists" do
    UserToken.where(user_id: @user.id).delete_all
    UserToken.create!(user: @user, status: "restricted")

    assert @harness.send(:restricted_session_exists?, @user)
  end

  test "restricted_session_exists? ignores expired restricted sessions" do
    UserToken.where(user_id: @user.id).delete_all
    UserToken.create!(
      user: @user,
      status: UserToken::STATUS_RESTRICTED,
      refresh_expires_at: 1.minute.ago,
    )

    assert_not @harness.send(:restricted_session_exists?, @user)
  end

  test "restricted_session_exists? returns false when no restricted session" do
    UserToken.where(user_id: @user.id).delete_all

    assert_not @harness.send(:restricted_session_exists?, @user)
  end

  test "find_restricted_sessions_scope returns correct relation for User" do
    relation = @harness.send(:find_restricted_sessions_scope, @user)

    assert_kind_of ActiveRecord::Relation, relation
  end

  test "restricted_session_expires_at returns correct time" do
    freeze_time do
      result = @harness.send(:restricted_session_expires_at)

      assert_equal 15.minutes.from_now.to_i, result.to_i
    end
  end

  test "store_pending_login_resource stores user id in session" do
    @harness.send(:store_pending_login_resource, @user)

    assert_equal @user.id, @harness.session[:pending_login_user_id]
  end

  test "store_pending_login_resource stores staff id in session" do
    staff = ::Staff.first
    @harness.send(:store_pending_login_resource, staff)

    assert_equal staff.id, @harness.session[:pending_login_staff_id]
  end
end

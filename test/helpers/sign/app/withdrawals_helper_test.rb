# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::App::WithdrawalsHelperTest < ActionView::TestCase
  include ActiveSupport::Testing::TimeHelpers

  ClientStub =
    Struct.new(:withdrawn, :recovery_deadline) do
      def withdrawn?
        withdrawn
      end
    end

  setup do
    extend Auth::App::WithdrawalsHelper
  end

  def current_client
    @current_user
  end

  test "user_withdrawn? returns true when user is withdrawn" do
    @current_user = ClientStub.new(true, nil)

    assert_predicate self, :user_withdrawn?
  end

  test "user_withdrawn? returns false when user not withdrawn" do
    @current_user = ClientStub.new(false, nil)

    assert_not_predicate self, :user_withdrawn?
  end

  test "user_withdrawn? returns false without current user" do
    @current_user = nil

    assert_not_predicate self, :user_withdrawn?
  end

  test "days_until_permanent_deletion returns nil when not withdrawn" do
    @current_user = ClientStub.new(false, nil)

    assert_nil days_until_permanent_deletion
  end

  test "days_until_permanent_deletion returns 0 when deadline has passed" do
    @current_user = ClientStub.new(true, 1.day.ago)

    assert_equal 0, days_until_permanent_deletion
  end

  test "days_until_permanent_deletion returns 0 when deadline missing" do
    @current_user = ClientStub.new(true, nil)

    assert_equal 0, days_until_permanent_deletion
  end

  test "days_until_permanent_deletion rounds up remaining days" do
    @current_user = ClientStub.new(true, nil)

    travel_to Time.zone.parse("2024-01-01 00:00:00") do
      @current_user.recovery_deadline = Time.zone.parse("2024-01-03 12:00:00")

      assert_equal 3, days_until_permanent_deletion
    end
  end

  test "recovery_period_expired? returns true after deadline" do
    @current_user = ClientStub.new(true, nil)

    travel_to Time.zone.parse("2024-01-02 00:00:00") do
      @current_user.recovery_deadline = Time.zone.parse("2024-01-01 00:00:00")

      assert_predicate self, :recovery_period_expired?
    end
  end

  test "recovery_period_expired? returns false when not withdrawn" do
    @current_user = ClientStub.new(false, 1.day.ago)

    assert_not_predicate self, :recovery_period_expired?
  end

  test "recovery_period_expired? returns false before deadline" do
    @current_user = ClientStub.new(true, 1.day.from_now)

    assert_not_predicate self, :recovery_period_expired?
  end

  test "recovery_period_expired? returns false when deadline is missing" do
    @current_user = ClientStub.new(true, nil)

    assert_not_predicate self, :recovery_period_expired?
  end

  test "recovery_period_expired? returns false without current user" do
    @current_user = nil

    assert_not_predicate self, :recovery_period_expired?
  end
end

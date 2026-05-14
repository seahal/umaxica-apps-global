# typed: false
# frozen_string_literal: true

require "test_helper"

class StaffCoverageTest < ActiveSupport::TestCase
  setup do
    OperatorIdentityStatus.find_or_create_by!(id: 1)
    OperatorIdentityStatus.find_or_create_by!(id: 2)
    OperatorVisibility.find_or_create_by!(id: 1)
    OperatorVisibility.find_or_create_by!(id: 2)
    @staff = Operator.create!(status_id: 2, visibility_id: 2)
  end

  test "operator? and user? predicates" do
    assert_predicate @staff, :operator?
    assert_not @staff.user?
  end

  test "public_id generation and normalization" do
    raw = Operator.generate_public_id

    assert_equal 16, raw.length

    assert_equal "ABC123", Operator.normalize_public_id(" abc-123_ ")
    assert_nil Operator.normalize_public_id(nil)
  end

  test "assign_public_id! on create" do
    s = Operator.new(status_id: 2, visibility_id: 2)

    assert_nil s.public_id
    s.valid?

    assert_not_nil s.public_id
    assert_equal 16, s.public_id.length
  end

  test "explicit blank public_id input" do
    s = Operator.new(status_id: 2, visibility_id: 2)
    s.public_id = "  "

    assert_not s.valid?
    assert_includes s.errors[:public_id], "を入力してください"
  end

  test "retry_on_public_id_collision" do
    # This is hard to test without heavy mocking, but we can try
    # We can stub Staff.exists? to return true once
    calls = 0
    Operator.stub(:exists?, ->(_) { (calls += 1) == 1 }) do
      s = Operator.create!(status_id: 2, visibility_id: 2)

      assert_not_nil s.public_id
    end
  end
end

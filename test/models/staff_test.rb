# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staffs
# Database name: operator
#
#  id                   :bigint           not null, primary key
#  lapses_at            :datetime         default(Infinity), not null
#  lock_version         :integer          default(0), not null
#  multi_factor_enabled :boolean          default(FALSE), not null
#  purge_at             :datetime         default(Infinity), not null
#  withdrawn_at         :datetime
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  public_id            :string(16)       not null
#  status_id            :bigint           default(2), not null
#  visibility_id        :bigint           default(2), not null
#
# Indexes
#
#  index_staffs_on_public_id      (public_id) UNIQUE
#  index_staffs_on_purge_at       (purge_at)
#  index_staffs_on_status_id      (status_id)
#  index_staffs_on_visibility_id  (visibility_id)
#  index_staffs_on_withdrawn_at   (withdrawn_at) WHERE (withdrawn_at IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => staff_statuses.id)
#  fk_rails_...  (visibility_id => staff_visibilities.id)
#

require "test_helper"

class StaffTest < ActiveSupport::TestCase
  NIL_UUID = "00000000-0000-0000-0000-000000000000"
  VALID_PUBLIC_ID = "ABCDEFGH2345WXYZ"
  SECOND_VALID_PUBLIC_ID = "BCDEFGHJ2345WXYZ"

  def setup
    [0, 1, 2, 3].each { |id| StaffVisibility.find_or_create_by!(id: id) }
    StaffTelephoneStatus.find_or_create_by!(id: StaffTelephoneStatus::UNVERIFIED)
    StaffEmailStatus.find_or_create_by!(id: StaffEmailStatus::UNVERIFIED)
    StaffTokenStatus.find_or_create_by!(id: StaffTokenStatus::ACTIVE)
  end

  # ==========================================================================
  # A. Normal cases (specification compliance)
  # ==========================================================================

  test "public_id is auto-generated when not specified" do
    staff = Staff.create!

    assert_predicate staff.public_id, :present?
  end

  test "auto-generated public_id is exactly 16 characters" do
    staff = Staff.create!

    assert_equal 16, staff.public_id.length
  end

  test "default visibility_id is staff (2)" do
    staff = Staff.create!

    assert_equal StaffVisibility::STAFF, staff.visibility_id
  end

  test "login_allowed? is false for reserved status" do
    staff = Staff.create!(public_id: Staff.generate_public_id, status_id: StaffStatus::RESERVED)

    assert_not staff.login_allowed?
  end

  test "login_allowed? remains true for nothing status while active" do
    staff = Staff.create!(public_id: Staff.generate_public_id, status_id: StaffStatus::NOTHING)

    assert_predicate staff, :login_allowed?
  end

  test "visibility association resolves to StaffVisibility with id 2 by default" do
    staff = Staff.create!

    assert_equal StaffVisibility::STAFF, staff.visibility.id
  end

  test "invalid visibility_id is rejected by foreign key" do
    staff = Staff.new(
      public_id: Staff.generate_public_id,
      status_id: StaffStatus::NOTHING,
      visibility_id: 9_999,
    )
    assert_raises(ActiveRecord::InvalidForeignKey) do
      staff.save!(validate: false)
    end
  end

  test "auto-generated public_id is uppercase" do
    staff = Staff.create!

    assert_equal staff.public_id, staff.public_id.upcase
  end

  test "auto-generated public_id contains only base32 characters" do
    staff = Staff.create!

    assert_match(/\A[0-9A-FGHJKMNPQRSTVWXYZ]{16}\z/, staff.public_id)
  end

  test "auto-generated public_id is unique across multiple records" do
    public_ids = Prosopite.pause { 10.times.map { Staff.create!.public_id } }

    assert_equal public_ids.uniq.size, public_ids.size
  end

  # ==========================================================================
  # B. Normalization (input equivalence)
  # Tests verify that various input formats are normalized to the same output.
  # This ensures case-insensitivity and tolerance for common formatting.
  # ==========================================================================

  test "normalization: lowercase input is converted to uppercase" do
    staff = Staff.new(public_id: "abcdefgh2345wxyz")
    staff.validate

    assert_equal VALID_PUBLIC_ID, staff.public_id
  end

  test "normalization: uppercase input remains uppercase" do
    staff = Staff.new(public_id: VALID_PUBLIC_ID)
    staff.validate

    assert_equal VALID_PUBLIC_ID, staff.public_id
  end

  test "normalization: mixed case input is converted to uppercase" do
    staff = Staff.new(public_id: "AbCdEfGh2345WxYz")
    staff.validate

    assert_equal VALID_PUBLIC_ID, staff.public_id
  end

  test "normalization: hyphens are removed before validation" do
    staff = Staff.new(public_id: "ABCD-EFGH-2345-WXYZ")
    staff.validate

    assert_equal VALID_PUBLIC_ID, staff.public_id
  end

  test "normalization: underscores are removed before validation" do
    staff = Staff.new(public_id: "ABCD_EFGH_2345_WXYZ")
    staff.validate

    assert_equal VALID_PUBLIC_ID, staff.public_id
  end

  test "normalization: leading/trailing whitespace is stripped" do
    staff = Staff.new(public_id: "  abcd-efgh-2345-wxyz  ")
    staff.validate

    assert_equal VALID_PUBLIC_ID, staff.public_id
  end

  test "normalization: multiple hyphens and underscores are all removed" do
    staff = Staff.new(public_id: "ab-cd_efgh-23_45wxyz")
    staff.validate

    assert_equal VALID_PUBLIC_ID, staff.public_id
  end

  test "save normalizes public_id to uppercase" do
    staff = Staff.create!(public_id: "abcd-efgh-2345-wxyz")

    staff.update!(public_id: "bcde-fghj-2345-wxyz")

    assert_equal SECOND_VALID_PUBLIC_ID, staff.reload.public_id
  end

  # ==========================================================================
  # C. Boundary Value Analysis
  # ==========================================================================

  test "boundary: length 15 is invalid" do
    staff = Staff.new(public_id: "ABCDEFGH2345WXY")

    assert_not staff.valid?
    assert_not_empty staff.errors[:public_id]
  end

  test "boundary: length 16 is valid" do
    staff = Staff.new(public_id: VALID_PUBLIC_ID)

    assert_predicate staff, :valid?
  end

  test "boundary: length 17 is invalid" do
    staff = Staff.new(public_id: "ABCDEFGH2345WXYZ2")

    assert_not staff.valid?
    assert_not_empty staff.errors[:public_id]
  end

  # ==========================================================================
  # D. Equivalence Partitioning
  # ==========================================================================

  test "equivalence: valid set - allowed base32 characters only (16 chars) is valid" do
    staff = Staff.new(public_id: VALID_PUBLIC_ID)

    assert_predicate staff, :valid?
  end

  test "equivalence: secure random base32 alphabet input is valid" do
    staff = Staff.new(public_id: "01ABCDGHJKMNPQRS")

    assert_predicate staff, :valid?
  end

  test "equivalence: invalid set - contains disallowed letter I" do
    staff = Staff.new(public_id: "I1ABCDGHJKMNPQRS")

    assert_not staff.valid?
    assert_not_empty staff.errors[:public_id]
  end

  test "equivalence: invalid set - contains disallowed letter L" do
    staff = Staff.new(public_id: "L1ABCDGHJKMNPQRS")

    assert_not staff.valid?
    assert_not_empty staff.errors[:public_id]
  end

  test "equivalence: invalid set - contains disallowed letter O" do
    staff = Staff.new(public_id: "O1ABCDGHJKMNPQRS")

    assert_not staff.valid?
    assert_not_empty staff.errors[:public_id]
  end

  test "equivalence: invalid set - contains disallowed letter U" do
    staff = Staff.new(public_id: "U1ABCDGHJKMNPQRS")

    assert_not staff.valid?
    assert_not_empty staff.errors[:public_id]
  end

  test "equivalence: invalid set - contains punctuation" do
    staff = Staff.new(public_id: "ABCD!FGH2345WXYZ")

    assert_not staff.valid?
    assert_not_empty staff.errors[:public_id]
  end

  test "equivalence: invalid set - contains non-ascii" do
    staff = Staff.new(public_id: "ABCDあFGH2345WXYZ")

    assert_not staff.valid?
    assert_not_empty staff.errors[:public_id]
  end

  test "equivalence: invalid set - valid characters but wrong length" do
    staff = Staff.new(public_id: "ABCDE")

    assert_not staff.valid?
  end

  test "equivalence: invalid set - nil input is rejected when explicitly provided" do
    staff = Staff.new(public_id: nil)

    assert_not staff.valid?
    assert_nil staff.public_id
    assert_not_empty staff.errors[:public_id]
  end

  test "equivalence: invalid set - empty string input is rejected" do
    staff = Staff.new(public_id: "")

    assert_not staff.valid?
    assert_equal "", staff.public_id
    assert_not_empty staff.errors[:public_id]
  end

  test "equivalence: invalid set - whitespace only input is rejected" do
    staff = Staff.new(public_id: "   ")

    assert_not staff.valid?
    assert_equal "", staff.public_id
    assert_not_empty staff.errors[:public_id]
  end

  test "equivalence: invalid set - separators only input is rejected" do
    staff = Staff.new(public_id: "--__--")

    assert_not staff.valid?
    assert_equal "", staff.public_id
    assert_not_empty staff.errors[:public_id]
  end

  # ==========================================================================
  # E. Negative testing (failure modes)
  # ==========================================================================

  test "negative: public_id with lowercase letters normalizes and remains valid" do
    staff = Staff.new(public_id: "abcdefgh2345wxy2")

    assert_predicate staff, :valid?
    assert_equal "ABCDEFGH2345WXY2", staff.public_id
  end

  test "negative: duplicate public_id is invalid (uniqueness)" do
    existing_staff = Staff.create!
    duplicate_staff = Staff.new(public_id: existing_staff.public_id)

    assert_not duplicate_staff.valid?
    assert_not_empty duplicate_staff.errors[:public_id]
  end

  test "negative: public_id presence validation is configured" do
    # Verify that the presence validation is configured on the model
    validators = Staff.validators_on(:public_id)
    presence_validator = validators.find { |v| v.is_a?(ActiveRecord::Validations::PresenceValidator) }

    assert_not_nil presence_validator
  end

  # ==========================================================================
  # F. Test determinism - collision retry test
  # ==========================================================================

  test "determinism: collision retry generates different public_id on second attempt" do
    # Create an existing staff first
    existing_staff = Staff.create!
    existing_public_id = existing_staff.public_id

    call_count = 0
    Staff.stub(
      :exists?, ->(conditions) {
                  call_count += 1
                  # First call: simulate collision (return true)
                  # Second call and onwards: no collision (return false)
                  call_count == 1 && conditions[:public_id] == existing_public_id
                },
    ) do
      new_staff = Staff.new
      # Stub generate_public_id to return existing_public_id first, then a different one
      generated_ids = [existing_public_id, SECOND_VALID_PUBLIC_ID]
      new_staff.stub(:generate_public_id, -> { generated_ids.shift || VALID_PUBLIC_ID }) do
        new_staff.valid?

        assert_equal SECOND_VALID_PUBLIC_ID, new_staff.public_id
      end
    end
  end

  test "retry_on_public_id_collision regenerates public_id and retries" do
    staff = Staff.new
    generated_ids = [SECOND_VALID_PUBLIC_ID]
    attempts = 0

    staff.stub(:assign_public_id!, -> { staff.public_id = generated_ids.shift }) do
      staff.send(:retry_on_public_id_collision) do
        attempts += 1
        raise ActiveRecord::RecordNotUnique, "duplicate key" if attempts == 1
      end
    end

    assert_equal 2, attempts
    assert_equal SECOND_VALID_PUBLIC_ID, staff.public_id
  end

  test "retry_on_public_id_collision logs and raises after retry limit" do
    staff = Staff.new(public_id: VALID_PUBLIC_ID)
    logger = Minitest::Mock.new

    logger.expect(:error, nil, [String])
    logger.expect(:error, nil, [String])

    error =
      assert_raises(ActiveRecord::RecordNotUnique) do
        Rails.stub(:logger, logger) do
          staff.stub(:assign_public_id!, -> { staff.public_id = VALID_PUBLIC_ID }) do
            staff.send(:retry_on_public_id_collision) do
              raise ActiveRecord::RecordNotUnique, "duplicate key"
            end
          end
        end
      end

    assert_equal "duplicate key", error.message
    logger.verify
  end

  test "determinism: auto-generated public_id does not collide with existing records" do
    # Create multiple staffs and ensure no collision
    Prosopite.pause { 10.times { Staff.create! } }

    public_ids = Staff.pluck(:public_id)

    assert_equal public_ids.uniq.size, public_ids.size
  end

  # ==========================================================================
  # Existing tests (refactored)
  # ==========================================================================

  test "should be valid with auto-generated public_id" do
    staff = Staff.create!

    assert_predicate staff, :valid?
  end

  test "should have timestamps" do
    staff = Staff.create!

    assert_not_nil staff.created_at
    assert_not_nil staff.updated_at
  end

  test "should have many telephones association" do
    staff = Staff.create!

    assert_equal "staff_id", staff.class.reflect_on_association(:staff_telephones).foreign_key
  end

  test "dependent behaviors for staff associations" do
    assert_equal :restrict_with_error,
                 Staff.reflect_on_association(:staff_emails).options[:dependent]
    assert_equal :restrict_with_error,
                 Staff.reflect_on_association(:staff_telephones).options[:dependent]
    assert_equal :nullify,
                 Staff.reflect_on_association(:staff_chronicles).options[:dependent]
    assert_equal :nullify,
                 Staff.reflect_on_association(:user_chronicles).options[:dependent]
    assert_equal :destroy,
                 Staff.reflect_on_association(:staff_secrets).options[:dependent]
    assert_equal :destroy,
                 Staff.reflect_on_association(:staff_tokens).options[:dependent]
    assert_equal :destroy,
                 Staff.reflect_on_association(:staff_notifications).options[:dependent]
  end

  test "staff? should return true" do
    staff = Staff.create!

    assert_predicate staff, :staff?
  end

  test "user? should return false" do
    staff = Staff.create!

    assert_not staff.user?
  end

  test "should set default status before creation" do
    staff = Staff.create!

    assert_equal StaffStatus::NOTHING, staff.status_id
  end

  test "association deletion: restriction by dependent emails" do
    staff = Staff.create!
    StaffEmail.create!(staff: staff, address: "staff_test@example.com")
    assert_no_difference("Staff.count") do
      assert_not staff.destroy
      assert_not_empty staff.errors[:base]
    end
  end

  test "association deletion: restriction by dependent telephones" do
    staff = Staff.create!
    StaffTelephone.create!(staff: staff, number: "+15559876543")
    assert_no_difference("Staff.count") do
      assert_not staff.destroy
      assert_not_empty staff.errors[:base]
    end
  end

  test "association deletion: destroys dependent staff_tokens" do
    staff = Staff.create!
    token = StaffToken.create!(
      staff: staff,
      lapses_at: 1.day.from_now,
    )
    staff.destroy
    assert_raise(ActiveRecord::RecordNotFound) { token.reload }
  end

  test "purge_at query excludes staffs with default purge_at" do
    staff = Staff.create!

    assert_not_includes Staff.where(purge_at: ..Time.current), staff
  end

  test "purge_at query includes staffs with past purge_at" do
    staff = Staff.create!(lapses_at: 2.days.ago, purge_at: 1.day.ago)

    assert_includes Staff.where(purge_at: ..Time.current), staff
  end

  private

  def root_workspace
    Workspace.find_or_create_by!(id: NIL_UUID) do |workspace|
      workspace.name = "Root Workspace"
      workspace.domain = "root.example.com"
      workspace.parent_organization = NIL_UUID
    end
  end
end

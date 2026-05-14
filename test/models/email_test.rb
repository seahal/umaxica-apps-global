# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: emails
#
#  id             :binary           default(""), not null, primary key
#  address        :string(1024)     not null
#  emailable_type :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  emailable_id   :binary           not null
#
require "test_helper"

class IdentityEmailTest < ActiveSupport::TestCase
  [OperatorEmail, UserEmail].each do |model|
    test "#{model} valid with address and confirm_policy" do
      record =
        model.new(
          address: "eg@example.com",
          confirm_policy: true,
        ).tap { |instance| assign_owner(instance) }

      assert_predicate record, :valid?
      assert_difference "#{model}.count", +1 do
        record.save!
      end
    end

    test "#{model} rejects blank address" do
      record = model.new(address: "", confirm_policy: true)
      assign_owner(record)

      assert_not record.valid?
    end

    test "#{model} enforces case-insensitive uniqueness" do
      record = model.new(address: "eg@example.com", confirm_policy: true)
      assign_owner(record)
      record.save!

      same_case = model.new(address: "eg@example.com", confirm_policy: true)
      assign_owner(same_case)

      upper_case = model.new(address: "EG@EXAMPLE.COM", confirm_policy: true)
      assign_owner(upper_case)

      assert_not same_case.valid?
      assert_not upper_case.valid?
    end

    test "#{model} downcases address on save" do
      mail_address = "A@B.C"
      rec = model.new(address: mail_address, confirm_policy: true)
      assign_owner(rec)
      rec.save!

      assert_equal mail_address.downcase, rec.reload.address
    end

    test "#{model} pass_code validations when address nil" do
      m = model.new(address: "valid@example.com")
      assign_owner(m)
      m.pass_code = 123_456

      assert_predicate m, :valid?
      m.pass_code = 12_345

      assert_not m.valid?
      m.pass_code = 1_234_567

      assert_not m.valid?
      m.pass_code = 0

      assert_not m.valid?
      m.pass_code = nil

      assert_predicate m, :valid?
    end

    test "#{model} invalid when both address and pass_code nil" do
      m = model.new(address: nil, pass_code: nil)
      assign_owner(m)

      assert_not m.valid?
    end
  end

  private

  def assign_owner(record)
    case record
    when UserEmail
      record.user = User.find_by!(public_id: "none_id")
    when OperatorEmail
      record.staff = Operator.find_by!(public_id: "CDEF2345GHJK67NM")
    end
  end
end

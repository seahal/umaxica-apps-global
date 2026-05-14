# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: telephones
#
#  id             :binary           not null, primary key
#  entryable_type :string
#  number         :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  entryable_id   :binary
#
require "test_helper"

class TelephoneTest < ActiveSupport::TestCase
  test "includes confirm attribute accessors" do
    telephone = OperatorTelephone.new

    telephone.confirm_policy = true
    telephone.confirm_using_mfa = false
    telephone.pass_code = "123456"

    assert telephone.confirm_policy
    assert_not telephone.confirm_using_mfa
    assert_equal "123456", telephone.pass_code
  end

  # Telephone numbers contain digits and symbols, so downcasing is not applicable
  # This test has been removed as the downcase behavior was removed from the Telephone concern

  test "confirm_policy acceptance skipped when number missing but pass_code present" do
    validator =
      OperatorTelephone.validators_on(:confirm_policy).find do |v|
        v.is_a?(ActiveModel::Validations::AcceptanceValidator)
      end

    assert_not_nil validator

    condition = Array(validator.options[:unless]).first

    assert_respond_to condition, :call

    skip_validation = OperatorTelephone.new(number: nil, pass_code: "654321")
    require_validation = OperatorTelephone.new(number: "user@example.com", pass_code: nil)

    assert condition.call(skip_validation)
    assert_not condition.call(require_validation)
  end

  test "pass_code validation skipped when pass_code missing but number present" do
    validator =
      OperatorTelephone.validators_on(:pass_code).find do |v|
        v.is_a?(ActiveModel::Validations::PresenceValidator)
      end

    assert_not_nil validator

    condition = Array(validator.options[:unless]).first

    assert_respond_to condition, :call

    skip_validation = OperatorTelephone.new(number: "user@example.com", pass_code: nil)
    require_validation = OperatorTelephone.new(number: nil, pass_code: "123456")

    assert condition.call(skip_validation)
    assert_not condition.call(require_validation)
  end
end

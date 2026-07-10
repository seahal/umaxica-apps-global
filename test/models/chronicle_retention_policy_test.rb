# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: chronicle_retention_policies
# Database name: chronicle
#
#  id            :bigint           not null, primary key
#  code          :string           not null
#  duration_days :integer          not null
#  name          :string           not null
#  permanent     :boolean          not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_chronicle_retention_policies_on_code  (code) UNIQUE
#

require "test_helper"

class ChronicleRetentionPolicyTest < ActiveSupport::TestCase
  test "valid with valid attributes" do
    policy = ChronicleRetentionPolicy.new(code: "test", name: "Test Policy", duration_days: 30, permanent: false)

    assert_predicate policy, :valid?
  end

  test "permanent policy with duration_days 1 is invalid" do
    policy = ChronicleRetentionPolicy.new(code: "perm", name: "Permanent", duration_days: 1, permanent: true)

    assert_predicate policy, :invalid?
  end

  test "permanent policy with duration_days 0 is valid" do
    policy = ChronicleRetentionPolicy.new(code: "perm", name: "Permanent", duration_days: 0, permanent: true)

    assert_predicate policy, :valid?
  end

  test "non-permanent policy with duration_days 0 is valid" do
    policy = ChronicleRetentionPolicy.new(code: "temp", name: "Temporary", duration_days: 0, permanent: false)

    assert_predicate policy, :valid?
  end

  test "has many chronicles" do
    assert_equal :has_many, ChronicleRetentionPolicy.reflect_on_association(:chronicles).macro
  end

  test "permanent policy with non-zero duration adds error message" do
    policy = ChronicleRetentionPolicy.new(code: "perm", name: "Permanent", duration_days: 1, permanent: true)

    assert_not policy.valid?
    assert_includes policy.errors[:duration_days], "must be 0 for permanent retention"
  end
end

# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: ip_occurrences
# Database name: occurrence
#
#  id           :bigint           not null, primary key
#  body         :string           default(""), not null
#  discarded_at :datetime         default(Infinity), not null
#  memo         :string           default(""), not null
#  purged_at    :datetime         default(Infinity), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  public_id    :string(21)       default(""), not null
#  status_id    :bigint           default(0), not null
#
# Indexes
#
#  index_ip_occurrences_on_body             (body) UNIQUE
#  index_ip_occurrences_on_body_created_at  (body,created_at)
#  index_ip_occurrences_on_public_id        (public_id) UNIQUE
#  index_ip_occurrences_on_purged_at        (purged_at)
#  index_ip_occurrences_on_status_id        (status_id)
#
# Foreign Keys
#
#  fk_ip_occurrences_on_status_id  (status_id => ip_occurrence_statuses.id)
#

require "test_helper"

class IpOccurrenceTest < ActiveSupport::TestCase
  fixtures :ip_occurrences

  test "defaults status_id to nothing" do
    record = IpOccurrence.new(body: "203.0.113.77", public_id: "X" * 21)

    assert_equal IpOccurrenceStatus::NOTHING, record.status_id
  end

  test "public_id length" do
    record = build_occurrence(IpOccurrence, body: "203.0.113.42", public_id: "A" * 20)

    assert_invalid_attribute(record, :public_id)
  end

  test "public_id format" do
    record = build_occurrence(IpOccurrence, body: "203.0.113.42", public_id: ("A" * 20) + "!")

    assert_invalid_attribute(record, :public_id)
  end

  test "public_id uniqueness" do
    existing = IpOccurrence.find_by!(public_id: "one_ip_occ_id_0000001")
    record = build_occurrence(IpOccurrence, body: "203.0.113.99", public_id: existing.public_id)

    assert_invalid_attribute(record, :public_id)
  end

  test "body presence" do
    record = build_occurrence(IpOccurrence, body: nil)

    assert_invalid_attribute(record, :body)
  end

  test "body uniqueness" do
    existing = IpOccurrence.find_by!(public_id: "one_ip_occ_id_0000001")
    record = build_occurrence(IpOccurrence, body: existing.body)

    assert_invalid_attribute(record, :body)
  end

  test "status_id presence" do
    record = build_occurrence(IpOccurrence, body: "203.0.113.42", status_id: nil)

    assert_invalid_attribute(record, :status_id)
  end

  test "memo length" do
    record = build_occurrence(IpOccurrence, body: "203.0.113.42", memo: "a" * 1025)

    assert_invalid_attribute(record, :memo)
  end

  test "public_id auto generated on create" do
    record = build_occurrence(IpOccurrence, body: "203.0.113.42", public_id: nil)

    assert_public_id_generated(record)
  end

  test "public_id preserved when provided" do
    custom_public_id = "Z" * 21
    record = build_occurrence(IpOccurrence, body: "203.0.113.42", public_id: custom_public_id)

    assert_public_id_preserved(record, custom_public_id)
  end

  test "lifecycle timestamps default" do
    record = build_occurrence(IpOccurrence, body: "198.51.100.10", public_id: "Y" * 21)

    assert_occurrence_lifecycle_defaults(record)
  end

  test "association deletion: destroys joining relations" do
    record = build_occurrence(IpOccurrence, body: "192.168.1.1")
    record.save!
    join = AreaIpOccurrence.create!(
      ip_occurrence: record,
      area_occurrence: AreaOccurrence.find_by!(public_id: "one_area_occ_id_00001"),
    )

    record.destroy
    assert_raise(ActiveRecord::RecordNotFound) { join.reload }
  end
end

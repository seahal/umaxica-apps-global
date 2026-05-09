# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: zip_occurrences
# Database name: occurrence
#
#  id         :bigint           not null, primary key
#  body       :string           default(""), not null
#  lapses_at  :datetime         default(Infinity), not null
#  memo       :string           default(""), not null
#  purge_at   :datetime         default(Infinity), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  public_id  :string(21)       default(""), not null
#  status_id  :bigint           default(0), not null
#
# Indexes
#
#  index_zip_occurrences_on_body       (body) UNIQUE
#  index_zip_occurrences_on_public_id  (public_id) UNIQUE
#  index_zip_occurrences_on_purge_at   (purge_at)
#  index_zip_occurrences_on_status_id  (status_id)
#
# Foreign Keys
#
#  fk_zip_occurrences_on_status_id  (status_id => zip_occurrence_statuses.id)
#

require "test_helper"

class ZipOccurrenceTest < ActiveSupport::TestCase
  fixtures :zip_occurrences, :zip_occurrence_statuses

  test "defaults status_id to nothing" do
    record = ZipOccurrence.new(body: "1800001", public_id: "X" * 21)

    assert_equal ZipOccurrenceStatus::NOTHING, record.status_id
  end

  test "public_id length" do
    record = build_occurrence(ZipOccurrence, body: "1500001", public_id: "A" * 20)

    assert_invalid_attribute(record, :public_id)
  end

  test "public_id format" do
    record = build_occurrence(ZipOccurrence, body: "1500001", public_id: ("A" * 20) + "!")

    assert_invalid_attribute(record, :public_id)
  end

  test "public_id uniqueness" do
    existing = zip_occurrences(:one)
    record = build_occurrence(ZipOccurrence, body: "1600001", public_id: existing.public_id)

    assert_invalid_attribute(record, :public_id)
  end

  test "body presence" do
    record = build_occurrence(ZipOccurrence, body: nil)

    assert_invalid_attribute(record, :body)
  end

  test "body uniqueness" do
    existing = ZipOccurrence.find_by!(public_id: "one_zip_occ_id_000001")
    record = build_occurrence(ZipOccurrence, body: existing.body)

    assert_invalid_attribute(record, :body)
  end

  test "status_id presence" do
    record = build_occurrence(ZipOccurrence, body: "1500001", status_id: nil)

    assert_invalid_attribute(record, :status_id)
  end

  test "memo length" do
    record = build_occurrence(ZipOccurrence, body: "1500001", memo: "a" * 1025)

    assert_invalid_attribute(record, :memo)
  end

  test "public_id auto generated on create" do
    record = build_occurrence(ZipOccurrence, body: "1500001", public_id: nil)

    assert_public_id_generated(record)
  end

  test "public_id preserved when provided" do
    custom_public_id = "Z" * 21
    record = build_occurrence(ZipOccurrence, body: "1500001", public_id: custom_public_id)

    assert_public_id_preserved(record, custom_public_id)
  end

  test "lifecycle timestamps default" do
    record = build_occurrence(ZipOccurrence, body: "1700001", public_id: "Y" * 21)

    assert_occurrence_lifecycle_defaults(record)
  end
end

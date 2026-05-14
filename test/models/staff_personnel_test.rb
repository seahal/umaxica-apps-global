# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_personnels
# Database name: personnel
#
#  id                    :bigint           not null, primary key
#  audience              :string           not null
#  issuer                :string           not null
#  last_authenticated_at :datetime
#  lock_version          :integer          default(0), not null
#  subject               :string           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  public_id             :string           default(""), not null
#  source_record_id      :bigint           not null
#  status_id             :bigint           default(0), not null
#
# Indexes
#
#  index_staff_personnels_on_issuer_and_subject_and_audience  (issuer,subject,audience) UNIQUE
#  index_staff_personnels_on_public_id                        (public_id) UNIQUE
#  index_staff_personnels_on_source_record_id                 (source_record_id) UNIQUE
#  index_staff_personnels_on_status_id                        (status_id)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => staff_personnel_statuses.id)
#
require "test_helper"

class OperatorPersonnelTest < ActiveSupport::TestCase
  setup do
    OperatorPersonnelStatus.ensure_defaults!
  end

  test "creates personnel scoped mapping" do
    personnel = OperatorPersonnel.create!(
      issuer: "https://id.example.test",
      subject: "staff-subject-1",
      audience: "apex_org",
      source_record_id: 201,
      status_id: OperatorPersonnelStatus::ACTIVE,
    )

    assert_predicate personnel.public_id, :present?
    assert_equal PersonnelRecord.connection_db_config.name, personnel.class.connection_db_config.name
    assert_equal OperatorPersonnelStatus::ACTIVE, personnel.status_id
  end

  test "requires oidc mapping fields" do
    personnel = OperatorPersonnel.new

    assert_not personnel.valid?
    assert personnel.errors.of_kind?(:issuer, :blank)
    assert personnel.errors.of_kind?(:subject, :blank)
    assert personnel.errors.of_kind?(:audience, :blank)
    assert personnel.errors.of_kind?(:source_record_id, :blank)
  end

  test "allows one mapping per issuer subject and audience" do
    OperatorPersonnel.create!(
      issuer: "https://id.example.test",
      subject: "staff-subject-2",
      audience: "apex_org",
      source_record_id: 202,
      status_id: OperatorPersonnelStatus::ACTIVE,
    )

    duplicate = OperatorPersonnel.new(
      issuer: "https://id.example.test",
      subject: "staff-subject-2",
      audience: "apex_org",
      source_record_id: 203,
      status_id: OperatorPersonnelStatus::ACTIVE,
    )

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:subject, :taken)
  end

  test "allows one mapping per source record" do
    OperatorPersonnel.create!(
      issuer: "https://id.example.test",
      subject: "staff-subject-3",
      audience: "apex_org",
      source_record_id: 204,
      status_id: OperatorPersonnelStatus::ACTIVE,
    )

    duplicate = OperatorPersonnel.new(
      issuer: "https://id.example.test",
      subject: "staff-subject-4",
      audience: "apex_org",
      source_record_id: 204,
      status_id: OperatorPersonnelStatus::ACTIVE,
    )

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:source_record_id, :taken)
  end
end

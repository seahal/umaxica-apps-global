# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_residents
# Database name: resident
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
#  index_user_residents_on_issuer_and_subject_and_audience  (issuer,subject,audience) UNIQUE
#  index_user_residents_on_public_id                        (public_id) UNIQUE
#  index_user_residents_on_source_record_id                 (source_record_id) UNIQUE
#  index_user_residents_on_status_id                        (status_id)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => user_resident_statuses.id)
#
require "test_helper"

class UserResidentTest < ActiveSupport::TestCase
  setup do
    UserResidentStatus.ensure_defaults!
  end

  test "creates resident scoped mapping" do
    resident = UserResident.create!(
      issuer: "https://id.example.test",
      subject: "user-subject-1",
      audience: "apex_app",
      source_record_id: 101,
      status_id: UserResidentStatus::ACTIVE,
    )

    assert_predicate resident.public_id, :present?
    assert_equal ResidentRecord.connection_db_config.name, resident.class.connection_db_config.name
    assert_equal UserResidentStatus::ACTIVE, resident.status_id
  end

  test "requires oidc mapping fields" do
    resident = UserResident.new

    assert_not resident.valid?
    assert resident.errors.of_kind?(:issuer, :blank)
    assert resident.errors.of_kind?(:subject, :blank)
    assert resident.errors.of_kind?(:audience, :blank)
    assert resident.errors.of_kind?(:source_record_id, :blank)
  end

  test "allows one mapping per issuer subject and audience" do
    UserResident.create!(
      issuer: "https://id.example.test",
      subject: "user-subject-2",
      audience: "apex_app",
      source_record_id: 102,
      status_id: UserResidentStatus::ACTIVE,
    )

    duplicate = UserResident.new(
      issuer: "https://id.example.test",
      subject: "user-subject-2",
      audience: "apex_app",
      source_record_id: 103,
      status_id: UserResidentStatus::ACTIVE,
    )

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:subject, :taken)
  end

  test "allows one mapping per source record" do
    UserResident.create!(
      issuer: "https://id.example.test",
      subject: "user-subject-3",
      audience: "apex_app",
      source_record_id: 104,
      status_id: UserResidentStatus::ACTIVE,
    )

    duplicate = UserResident.new(
      issuer: "https://id.example.test",
      subject: "user-subject-4",
      audience: "apex_app",
      source_record_id: 104,
      status_id: UserResidentStatus::ACTIVE,
    )

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:source_record_id, :taken)
  end
end

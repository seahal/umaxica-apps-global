# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_visitors
# Database name: visitor
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
#  index_client_visitors_on_issuer_and_subject_and_audience  (issuer,subject,audience) UNIQUE
#  index_client_visitors_on_public_id                        (public_id) UNIQUE
#  index_client_visitors_on_source_record_id                 (source_record_id) UNIQUE
#  index_client_visitors_on_status_id                        (status_id)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => client_visitor_statuses.id)
#
require "test_helper"

class VisitorClientTest < ActiveSupport::TestCase
  setup do
    VisitorClientStatus.ensure_defaults!
  end

  test "creates visitor scoped mapping" do
    visitor = VisitorClient.create!(
      issuer: "https://id.example.test",
      subject: "client-subject-1",
      audience: "apex_com",
      source_record_id: 301,
      status_id: VisitorClientStatus::ACTIVE,
    )

    assert_predicate visitor.public_id, :present?
    assert_equal VisitorRecord.connection_db_config.name, visitor.class.connection_db_config.name
    assert_equal VisitorClientStatus::ACTIVE, visitor.status_id
  end

  test "requires oidc mapping fields" do
    visitor = VisitorClient.new

    assert_not visitor.valid?
    assert visitor.errors.of_kind?(:issuer, :blank)
    assert visitor.errors.of_kind?(:subject, :blank)
    assert visitor.errors.of_kind?(:audience, :blank)
    assert visitor.errors.of_kind?(:source_record_id, :blank)
  end

  test "allows one mapping per issuer subject and audience" do
    VisitorClient.create!(
      issuer: "https://id.example.test",
      subject: "client-subject-2",
      audience: "apex_com",
      source_record_id: 302,
      status_id: VisitorClientStatus::ACTIVE,
    )

    duplicate = VisitorClient.new(
      issuer: "https://id.example.test",
      subject: "client-subject-2",
      audience: "apex_com",
      source_record_id: 303,
      status_id: VisitorClientStatus::ACTIVE,
    )

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:subject, :taken)
  end

  test "allows one mapping per source record" do
    VisitorClient.create!(
      issuer: "https://id.example.test",
      subject: "client-subject-3",
      audience: "apex_com",
      source_record_id: 304,
      status_id: VisitorClientStatus::ACTIVE,
    )

    duplicate = VisitorClient.new(
      issuer: "https://id.example.test",
      subject: "client-subject-4",
      audience: "apex_com",
      source_record_id: 304,
      status_id: VisitorClientStatus::ACTIVE,
    )

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:source_record_id, :taken)
  end
end

# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_contact_chronicles
# Database name: chronicle
#
#  id           :bigint           not null, primary key
#  actor_type   :string
#  lapses_at    :datetime         default(Infinity), not null
#  occurred_at  :datetime
#  purge_at     :datetime
#  subject_type :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  actor_id     :bigint
#  event_id     :bigint           not null
#  level_id     :bigint           not null
#  subject_id   :bigint           not null
#
# Indexes
#
#  index_app_contact_chronicles_on_actor_type_and_actor_id      (actor_type,actor_id)
#  index_app_contact_chronicles_on_event_id                     (event_id)
#  index_app_contact_chronicles_on_level_id                     (level_id)
#  index_app_contact_chronicles_on_subject_id                   (subject_id)
#  index_app_contact_chronicles_on_subject_type_and_subject_id  (subject_type,subject_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => app_contact_chronicle_events.id)
#  fk_rails_...  (level_id => app_contact_chronicle_levels.id)
#
require "test_helper"

class AppContactChronicleTest < ActiveSupport::TestCase
  test "belongs_to associations exist" do
    behavior = AppContactChronicle.new

    assert_respond_to behavior, :app_contact
    assert_respond_to behavior, :actor
    assert_respond_to behavior, :app_contact_chronicle_level
    assert_respond_to behavior, :app_contact_chronicle_event
  end

  test "active scope excludes expired chronicles" do
    assert_includes AppContactChronicle.active.to_sql, "expires_at"
  end

  test "app_contact method returns contact when subject_type matches" do
    contact = app_contacts(:one)
    behavior = AppContactChronicle.new(subject_id: contact.id, subject_type: "AppContact")

    assert_equal contact, behavior.app_contact
  end

  test "subject raises for unknown subject type" do
    behavior = AppContactChronicle.new(subject_id: 1, subject_type: "UnknownContact")

    assert_raises(ArgumentError) { behavior.subject }
  end

  test "app_contact= method sets subject_id and subject_type" do
    behavior = AppContactChronicle.new
    mock_contact = OpenStruct.new(id: 123)

    behavior.app_contact = mock_contact

    assert_equal 123, behavior.subject_id
    assert_equal "AppContact", behavior.subject_type
  end

  test "validates presence of subject_id" do
    behavior = AppContactChronicle.new(subject_id: nil, subject_type: "Test")

    assert_not behavior.valid?
    assert_predicate behavior.errors[:subject_id], :any?
  end

  test "validates presence of subject_type" do
    behavior = AppContactChronicle.new(subject_id: 1, subject_type: nil)

    assert_not behavior.valid?
    assert_predicate behavior.errors[:subject_type], :any?
  end
end

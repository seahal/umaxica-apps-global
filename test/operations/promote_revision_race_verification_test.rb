# typed: false
# frozen_string_literal: true

require "test_helper"

# Promotion is idempotent through a single unique index. When two promotions of
# the same revision race, the loser has to hand back the winner's version -- but
# only after proving that version really is this revision's complete snapshot.
# Handing back an incomplete or foreign version would publish an entry whose
# taxonomy does not match what was approved.
class PromoteRevisionRaceVerificationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def operation(revision)
    Publishing::PromoteRevisionOperation.new(revision: revision)
  end

  def revision_double(id:, single: 0, multiple: 0, media: 0)
    double = Object.new
    double.define_singleton_method(:id) { id }
    double.define_singleton_method(:single_taxonomy_assignments) { Struct.new(:count).new(single) }
    double.define_singleton_method(:multiple_taxonomy_assignments) { Struct.new(:count).new(multiple) }
    double.define_singleton_method(:media_usages) { Struct.new(:count).new(media) }
    double
  end

  def version_double(id:, revision_id:, single: 0, multiple: 0, media: 0)
    double = Object.new
    double.define_singleton_method(:id) { id }
    double.define_singleton_method(:entry_revision_id) { revision_id }
    double.define_singleton_method(:single_taxonomy_assignments) { Struct.new(:count).new(single) }
    double.define_singleton_method(:multiple_taxonomy_assignments) { Struct.new(:count).new(multiple) }
    double.define_singleton_method(:media_usages) { Struct.new(:count).new(media) }
    double
  end

  test "a version belonging to another revision is refused rather than handed back" do
    subject = operation(revision_double(id: 1))

    error =
      assert_raises(Publishing::PromoteRevisionOperation::RevisionMismatchError) do
        subject.send(:verify_complete!, version_double(id: 9, revision_id: 2))
      end

    assert_match(/version 9 does not belong to revision 1/, error.message)
  end

  test "a version missing taxonomy snapshots is refused with the counts on both sides" do
    subject = operation(revision_double(id: 1, single: 2, multiple: 3))

    error =
      assert_raises(Publishing::PromoteRevisionOperation::IncompleteVersionError) do
        subject.send(:verify_complete!, version_double(id: 9, revision_id: 1, single: 2, multiple: 1))
      end

    assert_match(%r{holds 2/1 taxonomy snapshots and 0 media usages, expected 2/3 and 0}, error.message)
  end

  test "a version that is this revision's complete snapshot is handed back" do
    subject = operation(revision_double(id: 1, single: 2, multiple: 3))
    version = version_double(id: 9, revision_id: 1, single: 2, multiple: 3)

    assert_equal version, subject.send(:verify_complete!, version)
  end

  # Only a collision on the idempotency index means another promotion won the
  # race; a duplicate sequence or public id is a genuine failure and must not be
  # swallowed as one.
  test "the idempotency index is the only uniqueness failure treated as a lost race" do
    Publishing::ContentFamilies::ENTRY_CLASSES.each do |entry_class|
      entry = entry_class.create!(locale: "en")
      revision = entry.revisions.create!(
        locale: "en", title: "Race", body: { "text" => "Race" },
        schema_version: 1, content_digest: Digest::SHA256.hexdigest("Race"), sequence: 1,
      )
      winner = Publishing::PromoteRevisionOperation.call(revision: revision)
      versions = revision.entry.versions
      prefix = "uidx_#{entry_class::SURFACE}_#{entry_class::AUDIENCE}_ver"

      # The database boundary reports the competing insert after the initial
      # lookup missed it; the operation must recover only a revision collision.
      versions.stub(:find_by, nil) do
        collision = ActiveRecord::RecordNotUnique.new("duplicate key violates #{prefix}_on_revision")
        versions.stub(:create!, ->(*) { raise collision }) do
          result = Publishing::PromoteRevisionOperation.call(revision: revision)

          assert_equal winner, result
        end

        other_indexes = versions.klass.lease_connection.indexes(versions.klass.table_name)
          .select(&:unique).map(&:name) - ["#{prefix}_on_revision"]
        assert_not_empty other_indexes

        other_indexes.each do |index_name|
          collision = ActiveRecord::RecordNotUnique.new("duplicate key violates #{index_name}")
          versions.stub(:create!, ->(*) { raise collision }) do
            error = assert_raises(ActiveRecord::RecordNotUnique) do
              Publishing::PromoteRevisionOperation.call(revision: revision)
            end

            assert_same collision, error
          end
        end
      end

      assert_equal [winner.id], entry.versions.pluck(:id)
    end
  end
end

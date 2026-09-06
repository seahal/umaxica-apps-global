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

  def revision_for(entry, sequence:)
    entry.revisions.create!(
      locale: "en", title: "Race", body: { "text" => "Race" },
      schema_version: 1, content_digest: Digest::SHA256.hexdigest("Race"), sequence: sequence,
    )
  end

  def version_attributes(entry, revision:, sequence:)
    entry.versions.create!(
      entry_revision: revision, locale: revision.locale, title: revision.title,
      body: revision.body, schema_version: revision.schema_version,
      content_digest: revision.content_digest, sequence: sequence,
    )
  end

  # A failed statement aborts the surrounding PostgreSQL transaction, and the
  # test itself runs in one, so each deliberate violation needs its own
  # savepoint to roll back to.
  def capture_unique_violation(entry)
    assert_raises(ActiveRecord::RecordNotUnique) do
      entry.class.transaction(requires_new: true) { yield }
    end
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

  # The stub-driven test below builds its RecordNotUnique by hand, so it can only
  # reach the message fallback. The branch that actually runs in production reads
  # PostgreSQL's structured PG_DIAG_CONSTRAINT_NAME field, which only a genuine
  # violation carries, so prove the classification against real errors too.
  test "a real PostgreSQL violation is classified by the index it actually names" do
    entry_class = Publishing::ContentFamilies::ENTRY_CLASSES.first
    entry = entry_class.create!(locale: "en")
    revision = revision_for(entry, sequence: 1)
    winner = Publishing::PromoteRevisionOperation.call(revision: revision)
    subject = operation(revision)
    prefix = "uidx_#{entry_class::SURFACE}_#{entry_class::AUDIENCE}_ver"

    # Same revision as the winner: the idempotency index is what gives way.
    revision_collision =
      capture_unique_violation(entry) do
        version_attributes(entry, revision: revision, sequence: winner.sequence + 1)
      end

    assert_equal "#{prefix}_on_revision", subject.send(:violated_constraint, revision_collision)
    assert subject.send(:idempotency_violation?, revision_collision, "#{prefix}_on_revision")

    # A different revision reusing the winner's sequence: a genuine failure that
    # must never be read as a lost race.
    other_revision = revision_for(entry, sequence: 2)
    sequence_collision =
      capture_unique_violation(entry) do
        version_attributes(entry, revision: other_revision, sequence: winner.sequence)
      end

    assert_equal "#{prefix}_seq", subject.send(:violated_constraint, sequence_collision)
    assert_not subject.send(:idempotency_violation?, sequence_collision, "#{prefix}_on_revision")
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
      owner = revision.entry
      prefix = "uidx_#{entry_class::SURFACE}_#{entry_class::AUDIENCE}_ver"

      unique_index_names =
        owner.versions.klass.lease_connection
          .indexes(owner.versions.klass.table_name)
          .select(&:unique).map(&:name)
      revision_index = "#{prefix}_on_revision"

      assert_includes unique_index_names, revision_index
      other_indexes = unique_index_names - [revision_index]

      assert_not_empty other_indexes

      # A versions relation whose #create! always loses a chosen unique race and
      # whose lookups behave as if the winning row is already committed. The
      # operation reloads `owner` inside `with_lock`, which resets any relation
      # captured earlier, so the stub sits on the record itself.
      losing_versions =
        lambda do |index_name|
          fake = Object.new
          fake.define_singleton_method(:find_by) { |*| nil }
          fake.define_singleton_method(:find_by!) { |*| winner }
          fake.define_singleton_method(:maximum) { |*| 0 }
          fake.define_singleton_method(:create!) do |*|
            raise ActiveRecord::RecordNotUnique,
                  %(PG::UniqueViolation: ERROR: duplicate key value violates unique constraint "#{index_name}")
          end
          fake
        end

      # A collision on the revision idempotency index means another promotion won
      # the race: the loser re-reads and hands back the winner's version.
      owner.stub(:versions, losing_versions.call(revision_index)) do
        assert_equal winner, Publishing::PromoteRevisionOperation.call(revision: revision)
      end

      # A duplicate sequence, public id, or any other unique violation is a
      # genuine failure and must propagate unswallowed.
      other_indexes.each do |index_name|
        owner.stub(:versions, losing_versions.call(index_name)) do
          error =
            assert_raises(ActiveRecord::RecordNotUnique) do
              Publishing::PromoteRevisionOperation.call(revision: revision)
            end

          assert_match index_name, error.message
        end
      end

      assert_equal [winner.id], entry.versions.reload.pluck(:id)
    end
  end
end

# frozen_string_literal: true

require_relative "../migration_support/publishing_schema"

# Copies existing publishing_media_usages rows into the owner-explicit tables,
# drops the exclusive-arc table, and attaches the same integrity triggers the
# taxonomy assignments already use.
#
# INSERT...SELECT is used instead of application models so this migration does
# not depend on future Publishing::* class shape, and so the copy is one
# statement per owner rather than a row loop. Rails DSL cannot express that
# set-based copy, PostgreSQL triggers, or CONSTRAINT TRIGGER completeness.
class SplitPublishingMediaUsages < ActiveRecord::Migration[8.2]
  USAGE_COLUMNS = %w(
    public_id media_file_id entry_id locale role field_path block_path position
    alt_text caption presentation_metadata created_at updated_at
  ).freeze

  def up
    safety_assured do
      copy_owned_rows(
        target: :publishing_revision_media_usages,
        owner_id: :entry_revision_id,
      )
      copy_owned_rows(
        target: :publishing_version_media_usages,
        owner_id: :entry_version_id,
      )
      drop_table(:publishing_media_usages)
      attach_integrity_triggers
    end
  end

  def down
    safety_assured do
      detach_integrity_triggers
      recreate_union_table
      copy_union_rows(
        source: :publishing_revision_media_usages,
        owner_id: :entry_revision_id,
      )
      copy_union_rows(
        source: :publishing_version_media_usages,
        owner_id: :entry_version_id,
      )
    end
  end

  private

  def copy_owned_rows(target:, owner_id:)
    quoted_columns = USAGE_COLUMNS.join(", ")
    execute(<<~SQL.squish)
      INSERT INTO #{target} (#{quoted_columns}, #{owner_id})
      SELECT #{quoted_columns}, #{owner_id}
      FROM publishing_media_usages
      WHERE #{owner_id} IS NOT NULL
    SQL
  end

  def copy_union_rows(source:, owner_id:)
    quoted_columns = USAGE_COLUMNS.join(", ")
    execute(<<~SQL.squish)
      INSERT INTO publishing_media_usages (#{quoted_columns}, #{owner_id})
      SELECT #{quoted_columns}, #{owner_id}
      FROM #{source}
    SQL
  end

  # rubocop:disable Metrics/MethodLength -- reconstructing the retired union table is one reversible schema block
  def recreate_union_table
    create_table(:publishing_media_usages) do |t|
      t.string(:public_id, limit: 21, null: false)
      t.references(:media_file, null: false, foreign_key: { to_table: :publishing_media_files, on_delete: :restrict })
      t.references(:entry, null: false, foreign_key: { to_table: :publishing_entries, on_delete: :restrict })
      t.bigint(:entry_revision_id)
      t.bigint(:entry_version_id)
      t.string(:locale, null: false)
      t.string(:role, null: false)
      t.string(:field_path)
      t.string(:block_path)
      t.integer(:position, null: false, default: 0)
      t.string(:alt_text)
      t.text(:caption)
      t.jsonb(:presentation_metadata)
      t.timestamps(null: false)
    end
    add_index(:publishing_media_usages, :public_id, unique: true)
    add_check_constraint(
      :publishing_media_usages, PublishingSchema::PUBLIC_ID,
      name: "chk_publishing_media_usages_public_id",
    )
    add_check_constraint(
      :publishing_media_usages, "num_nonnulls(entry_revision_id, entry_version_id) = 1",
      name: "chk_publishing_media_owner_xor",
    )
    add_check_constraint(
      :publishing_media_usages, "position >= 0",
      name: "chk_publishing_media_position",
    )
    add_check_constraint(
      :publishing_media_usages, "field_path IS NOT NULL OR block_path IS NOT NULL",
      name: "chk_publishing_media_path",
    )
    add_check_constraint(
      :publishing_media_usages,
      "presentation_metadata IS NULL OR jsonb_typeof(presentation_metadata) = 'object'",
      name: "chk_publishing_presentation_metadata",
    )
    add_index(
      :publishing_media_usages, %i(entry_revision_id role field_path block_path position),
      unique: true, where: "entry_revision_id IS NOT NULL",
      name: "uidx_publishing_revision_media_position",
    )
    add_index(
      :publishing_media_usages, %i(entry_version_id role field_path block_path position),
      unique: true, where: "entry_version_id IS NOT NULL",
      name: "uidx_publishing_version_media_position",
    )
    add_foreign_key(
      :publishing_media_usages, :publishing_entry_revisions,
      column: %i(entry_revision_id entry_id), primary_key: %i(id entry_id),
      on_delete: :restrict, name: "fk_publishing_media_revision_entry",
    )
    add_foreign_key(
      :publishing_media_usages, :publishing_entry_versions,
      column: %i(entry_version_id entry_id), primary_key: %i(id entry_id),
      on_delete: :restrict, name: "fk_publishing_media_version_entry",
    )
  end
  # rubocop:enable Metrics/MethodLength

  # rubocop:disable Metrics/MethodLength -- trigger SQL is one integrity attachment, not application logic
  # rubocop:disable I18n/RailsI18n/DecorateString -- DDL strings are not user-facing copy
  def attach_integrity_triggers
    execute(<<~SQL.squish)
      CREATE TRIGGER trg_publishing_revision_media_usages_promoted
      BEFORE INSERT OR UPDATE OR DELETE ON public.publishing_revision_media_usages
      FOR EACH ROW EXECUTE FUNCTION publishing_promoted_revision_guard();
    SQL
    execute(<<~SQL.squish)
      CREATE TRIGGER trg_publishing_version_media_usages_immutable
      BEFORE UPDATE OR DELETE ON public.publishing_version_media_usages
      FOR EACH ROW EXECUTE FUNCTION publishing_reject_mutation();
    SQL
    execute(<<~SQL.squish)
      CREATE FUNCTION publishing_assert_version_media_complete() RETURNS trigger AS $$
      DECLARE
        target_version_id bigint;
        source_revision_id bigint;
        mismatch integer;
      BEGIN
        IF TG_TABLE_NAME = 'publishing_entry_versions' THEN
          target_version_id := NEW.id;
        ELSE
          target_version_id := NEW.entry_version_id;
        END IF;

        SELECT entry_revision_id INTO source_revision_id
        FROM public.publishing_entry_versions WHERE id = target_version_id;
        IF source_revision_id IS NULL THEN RETURN NULL; END IF;

        SELECT count(*) INTO mismatch FROM (
          (
            SELECT media_file_id, role, field_path, block_path, position
            FROM public.publishing_revision_media_usages
            WHERE entry_revision_id = source_revision_id
            EXCEPT ALL
            SELECT media_file_id, role, field_path, block_path, position
            FROM public.publishing_version_media_usages
            WHERE entry_version_id = target_version_id
          )
          UNION ALL
          (
            SELECT media_file_id, role, field_path, block_path, position
            FROM public.publishing_version_media_usages
            WHERE entry_version_id = target_version_id
            EXCEPT ALL
            SELECT media_file_id, role, field_path, block_path, position
            FROM public.publishing_revision_media_usages
            WHERE entry_revision_id = source_revision_id
          )
        ) AS media_difference;
        IF mismatch > 0 THEN
          RAISE EXCEPTION
            'publishing media: version % usages do not match revision %',
            target_version_id, source_revision_id
            USING ERRCODE = 'integrity_constraint_violation';
        END IF;

        RETURN NULL;
      END;
      $$ LANGUAGE plpgsql SET search_path = pg_catalog, public;
    SQL
    %w(publishing_entry_versions publishing_version_media_usages).each do |table|
      execute(<<~SQL.squish)
        CREATE CONSTRAINT TRIGGER trg_#{table}_media_complete
        AFTER INSERT ON public.#{table}
        DEFERRABLE INITIALLY DEFERRED
        FOR EACH ROW EXECUTE FUNCTION publishing_assert_version_media_complete();
      SQL
    end
  end
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable I18n/RailsI18n/DecorateString

  def detach_integrity_triggers
    execute("DROP TRIGGER IF EXISTS trg_publishing_revision_media_usages_promoted ON public.publishing_revision_media_usages")
    execute("DROP TRIGGER IF EXISTS trg_publishing_version_media_usages_immutable ON public.publishing_version_media_usages")
    execute("DROP TRIGGER IF EXISTS trg_publishing_entry_versions_media_complete ON public.publishing_entry_versions")
    execute("DROP TRIGGER IF EXISTS trg_publishing_version_media_usages_media_complete ON public.publishing_version_media_usages")
    execute("DROP FUNCTION IF EXISTS publishing_assert_version_media_complete() CASCADE")
  end
end

# frozen_string_literal: true

require "test_helper"

module Publishing
  class MediaUsageOwnershipTest < ActiveSupport::TestCase
    setup do
      @edition = publishing_edition(audience: "app", surface: "docs", locale: "ja")
      @entry = publishing_draft(edition: @edition, slug: "media-owner", title: "Media Owner")
      @revision = @entry.current_revision
      @media_file = publishing_media_file
    end

    test "publishing_media_usages no longer exists" do
      assert_not PublishingRecord.connection.table_exists?("publishing_media_usages")
      assert_not Rails.root.join("app/models/publishing/media_usage.rb").exist?
    end

    test "revision media usages have a required revision owner and no version owner column" do
      columns = PublishingRecord.connection.columns("publishing_revision_media_usages").map(&:name)

      assert_includes columns, "entry_revision_id"
      assert_not_includes columns, "entry_version_id"
      revision_owner =
        PublishingRecord.connection.columns("publishing_revision_media_usages")
          .find { |column| column.name == "entry_revision_id" }

      assert_not revision_owner.null
    end

    test "version media usages have a required version owner and no revision owner column" do
      columns = PublishingRecord.connection.columns("publishing_version_media_usages").map(&:name)

      assert_includes columns, "entry_version_id"
      assert_not_includes columns, "entry_revision_id"
      version_owner =
        PublishingRecord.connection.columns("publishing_version_media_usages")
          .find { |column| column.name == "entry_version_id" }

      assert_not version_owner.null
    end

    test "revision media remains editable until the revision is promoted" do
      usage = publishing_revision_media_usage(revision: @revision, media_file: @media_file)

      usage.update!(position: 3, caption: "draft")

      assert_equal 3, usage.reload.position
      assert_equal "draft", usage.caption
      assert_nothing_raised { usage.destroy! }
    end

    test "duplicate revision media positions are rejected" do
      publishing_revision_media_usage(revision: @revision, media_file: @media_file, position: 0)

      assert_raises(ActiveRecord::RecordNotUnique) do
        publishing_revision_media_usage(
          revision: @revision, media_file: publishing_media_file, position: 0,
        )
      end
    end

    test "promotion copies revision media onto the immutable version" do
      publishing_revision_media_usage(
        revision: @revision, media_file: @media_file, role: "hero", position: 0, field_path: "hero",
      )
      second = publishing_media_file
      publishing_revision_media_usage(
        revision: @revision, media_file: second, role: "body", position: 1, field_path: "body.blocks.0",
      )

      version = PromoteRevisionOperation.call(revision: @revision)
      copied = version.media_usages.order(:position)

      assert_equal 2, copied.size
      assert_equal [@media_file.id, second.id], copied.map(&:media_file_id)
      assert_equal %w(hero body), copied.map(&:role)
      assert_equal [0, 1], copied.map(&:position)
    end

    test "released version media is immutable through active record and postgresql" do
      publishing_revision_media_usage(revision: @revision, media_file: @media_file)
      version = PromoteRevisionOperation.call(revision: @revision)
      usage = version.media_usages.sole

      assert_raises(ActiveRecord::ReadOnlyRecord) { usage.update!(caption: "changed") }
      assert_raises(ActiveRecord::ReadOnlyRecord) { usage.destroy! }
      assert_database_rejects do
        PublishingRecord.lease_connection.execute(
          "UPDATE publishing_version_media_usages SET caption = 'x' WHERE id = #{usage.id}",
        )
      end
      assert_database_rejects do
        PublishingRecord.lease_connection.execute(
          "DELETE FROM publishing_version_media_usages WHERE id = #{usage.id}",
        )
      end
    end

    test "a promoted revision can no longer change its media usages" do
      publishing_revision_media_usage(revision: @revision, media_file: @media_file)
      PromoteRevisionOperation.call(revision: @revision)

      assert_database_rejects do
        publishing_revision_media_usage(
          revision: @revision, media_file: publishing_media_file, position: 1, field_path: "body.blocks.1",
        )
      end
    end

    test "restore copies version media onto a new editable revision" do
      publishing_revision_media_usage(
        revision: @revision, media_file: @media_file, role: "hero", field_path: "hero",
      )
      version = PromoteRevisionOperation.call(revision: @revision)

      restored = RestoreVersionOperation.call(version:)
      copied = restored.media_usages.sole

      assert_equal @media_file.id, copied.media_file_id
      assert_equal "hero", copied.role
      copied.update!(caption: "restored draft")

      assert_equal "restored draft", copied.reload.caption
    end

    test "split migration copies revision and version owned rows by owner predicate" do
      source = Rails.root.join("db/publishing_migrate/20260903180100_split_publishing_media_usages.rb").read

      assert_includes source, "FROM publishing_media_usages"
      assert_includes source, "WHERE \#{owner_id} IS NOT NULL"
      assert_includes source, "drop_table(:publishing_media_usages)"
    end
  end
end

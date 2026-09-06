# frozen_string_literal: true

require "test_helper"

module Publishing
  class EncryptedContentStorageTest < ActiveSupport::TestCase
    PLAIN_TITLE = "Unique plaintext title for ciphertext proof"
    PLAIN_SUMMARY = "Unique plaintext summary for ciphertext proof"
    PLAIN_BODY = { "text" => "Unique plaintext body for ciphertext proof" }.freeze

    test "docs/app revision ciphertext is not stored as plaintext" do
      entry = publishing_draft(audience: "app", surface: "docs", slug: "enc-rev", title: PLAIN_TITLE)
      revision = entry.current_revision
      revision.update!(summary: PLAIN_SUMMARY, body: PLAIN_BODY)

      revision.reload
      assert_equal PLAIN_TITLE, revision.title
      assert_equal PLAIN_SUMMARY, revision.summary
      assert_equal PLAIN_BODY, revision.body
      assert_kind_of Hash, revision.body

      raw = raw_row(revision)
      refute_includes raw.fetch("title"), PLAIN_TITLE
      refute_includes raw.fetch("summary"), PLAIN_SUMMARY
      refute_includes raw.fetch("body"), PLAIN_BODY.fetch("text")

      other = publishing_draft(audience: "app", surface: "docs", slug: "enc-rev-2", title: PLAIN_TITLE)
      other.current_revision.update!(summary: PLAIN_SUMMARY, body: PLAIN_BODY)
      other_raw = raw_row(other.current_revision)
      refute_equal raw.fetch("title"), other_raw.fetch("title")
      refute_equal raw.fetch("body"), other_raw.fetch("body")
    end

    test "docs/app version ciphertext is written at insert and stays immutable" do
      entry = publishing_draft(audience: "app", surface: "docs", slug: "enc-ver", title: PLAIN_TITLE)
      entry.current_revision.update!(summary: PLAIN_SUMMARY, body: PLAIN_BODY)
      version = PromoteRevisionOperation.call(revision: entry.current_revision)

      assert_equal PLAIN_TITLE, version.title
      assert_kind_of Hash, version.body
      raw = raw_row(version)
      refute_includes raw.fetch("title"), PLAIN_TITLE
      refute_includes raw.fetch("body"), PLAIN_BODY.fetch("text")
      assert_raises(ActiveRecord::ReadOnlyRecord) { version.update!(title: "nope") }
    end

    # `body` is serialized as JSON and encrypted, so anything that is not an object still round
    # trips through the coder and reaches PostgreSQL as valid ciphertext. Nothing downstream --
    # the CMS body editor, the public renderer -- can index into a bare string or array, so the
    # model refuses it before the column does.
    test "a body that is not a JSON object is refused with a readable error" do
      entry = publishing_draft(audience: "app", surface: "docs", slug: "enc-shape", title: PLAIN_TITLE)
      revision = entry.current_revision

      [["text"], "text", 42, nil].each do |body|
        revision.body = body

        assert_not revision.valid?, body.inspect
        assert_equal ["must be a JSON object"], revision.errors[:body], body.inspect
      end
    end

    private

    def raw_row(record)
      connection = record.class.connection
      table = connection.quote_table_name(record.class.table_name)
      connection.select_one("SELECT title, summary, body FROM #{table} WHERE id = #{record.id.to_i}")
    end
  end
end

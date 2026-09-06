# frozen_string_literal: true

require "test_helper"

module Publishing
  class PublishEntryFormTest < ActiveSupport::TestCase
    test "no effective_from means publish now, which the operation reads as a nil time" do
      form = PublishEntryForm.new(effective_from_text: nil)

      assert_predicate form, :valid?
      assert_nil form.effective_from

      blank = PublishEntryForm.new(effective_from_text: "")

      assert_predicate blank, :valid?
      assert_nil blank.effective_from
    end

    test "an ISO 8601 value is parsed into a time" do
      form = PublishEntryForm.new(effective_from_text: "2026-09-08T15:04")

      assert_predicate form, :valid?
      assert_equal Time.zone.iso8601("2026-09-08T15:04"), form.effective_from
    end

    # `Time.zone.parse` reads a best effort out of almost anything, and a window opened at a time
    # nobody chose is worse than a rejected form.
    test "a value that is not a date and time is refused rather than guessed at" do
      ["next tuesday-ish", "soon", "2026-13-45T99:99", "publish"].each do |text|
        form = PublishEntryForm.new(effective_from_text: text)

        assert_not form.valid?, text
        assert_equal "must be a date and time", form.message_hash.fetch(:effective_from), text
      end
    end
  end
end

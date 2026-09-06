# frozen_string_literal: true

require "test_helper"

module Publishing
  # The staff CMS hands this form a body typed by hand into a textarea, so every way that text can
  # fail to be a JSON object has to become a named error the edit view can render, never an
  # exception and never a silently coerced value.
  class ReviseEntryFormTest < ActiveSupport::TestCase
    self.fixture_table_names = []

    def form(**attributes)
      ReviseEntryForm.new({ title: "Title", body_text: '{"text":"body"}', lock_version: 0 }.merge(attributes))
    end

    test "a well-formed object body is accepted and exposed as the parsed hash" do
      subject = form(body_text: '{"text":"body","blocks":[{"kind":"p"}]}')

      assert_predicate subject, :valid?
      assert_equal({ "text" => "body", "blocks" => [{ "kind" => "p" }] }, subject.parsed_body)
      assert_empty subject.message_hash
    end

    test "a blank title is refused" do
      subject = form(title: "  ")

      assert_not subject.valid?
      assert_equal "can't be blank", subject.message_hash.fetch(:title)
    end

    test "a blank body is refused as a missing object rather than parsed" do
      subject = form(body_text: "")

      assert_not subject.valid?
      assert_equal "must be a JSON object", subject.message_hash.fetch(:body)
      assert_nil subject.parsed_body
    end

    test "unparsable JSON is refused rather than raising out of the form" do
      subject = form(body_text: "{not json")

      assert_not subject.valid?
      assert_equal "must be valid JSON", subject.message_hash.fetch(:body)
      assert_nil subject.parsed_body
    end

    # An array, a string and a number are all valid JSON. A revision body is a document, so only an
    # object may pass; otherwise the operation would persist a body no reader can index into.
    test "valid JSON that is not an object is refused" do
      ['["a"]', '"text"', "42", "null"].each do |body_text|
        subject = form(body_text: body_text)

        assert_not subject.valid?, "#{body_text} should not be a valid revision body"
        assert_equal "must be a JSON object", subject.message_hash.fetch(:body)
        assert_nil subject.parsed_body
      end
    end

    test "lock_version is cast to an integer so a form field string still compares" do
      assert_equal 3, form(lock_version: "3").lock_version
    end

    test "message_hash reports every failing attribute at once" do
      subject = form(title: nil, body_text: "{not json")

      assert_not subject.valid?
      assert_equal %w(title body).to_set, subject.message_hash.keys.map(&:to_s).to_set
    end

    # The form is never saved, so anything that treats it as a record has to see a new object.
    test "the form is not persisted" do
      assert_not_predicate form, :persisted?
    end
  end
end

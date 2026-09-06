# frozen_string_literal: true

require "test_helper"

module Publishing
  # The slug rule here is the one PostgreSQL enforces (`chk_<cell>_slug_format`):
  # `^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$`. These cases walk its edges, because a slug the form
  # accepts and the database rejects would surface as a 500 on a staff form.
  class CreateEntryFormTest < ActiveSupport::TestCase
    def form(attributes)
      CreateEntryForm.new({
        title: "Title",
        summary: "Summary",
        body_text: { "text" => "body" }.to_json,
        locale: "ja",
        slug: "a-slug",
      }.merge(attributes))
    end

    test "a complete submission is valid and exposes the parsed body" do
      subject = form({})

      assert_predicate subject, :valid?
      assert_equal({ "text" => "body" }, subject.parsed_body)
    end

    test "slugs at the edges of the database format are accepted" do
      %w(a 0 ab a-b a--b a1-2b abcdefghijklmnopqrstuvwxyz0123456789).each do |slug|
        assert_predicate form(slug: slug), :valid?, slug
      end
    end

    test "slugs the database format would reject are refused with a message" do
      ["", "-a", "a-", "A", "aB", "a_b", "a b", "a.b", "-", "ひらがな"].each do |slug|
        subject = form(slug: slug)

        assert_not subject.valid?, slug.inspect
        assert_includes subject.message_hash.keys, :slug, slug.inspect
      end
    end

    test "a locale the application does not serve is refused" do
      subject = form(locale: "fr")

      assert_not subject.valid?
      assert_equal "must be one of en, ja", subject.message_hash.fetch(:locale)
    end

    test "every serveable locale is accepted" do
      I18n.available_locales.each do |locale|
        assert_predicate form(locale: locale.to_s), :valid?, locale.to_s
      end
    end

    test "a body that is not a JSON object is refused before the operation runs" do
      { "{" => "must be valid JSON", "[1,2]" => "must be a JSON object", "" => "must be a JSON object" }
        .each do |body_text, message|
          subject = form(body_text: body_text)

          assert_not subject.valid?, body_text.inspect
          assert_equal message, subject.message_hash.fetch(:body), body_text.inspect
        end
    end

    test "a blank title is refused" do
      subject = form(title: "  ")

      assert_not subject.valid?
      assert_equal "can't be blank", subject.message_hash.fetch(:title)
    end
  end
end

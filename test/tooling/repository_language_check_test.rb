# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "tmpdir"

class RepositoryLanguageCheckTest < Minitest::Test
  SCRIPT = File.expand_path("../../bin/repository-language-check", __dir__)

  def test_accepts_english_repository_prose
    Dir.mktmpdir do |directory|
      path = File.join(directory, "plan.md")
      # rubocop:disable I18n/RailsI18n/DecorateString
      File.write(path, "# Plan\n\nKeep repository prose in English.\n")
      # rubocop:enable I18n/RailsI18n/DecorateString

      _stdout, stderr, status = Open3.capture3(SCRIPT, path)

      assert_predicate status, :success?, stderr
    end
  end

  def test_reports_japanese_repository_prose_with_its_line_number
    Dir.mktmpdir do |directory|
      path = File.join(directory, "plan.md")
      File.write(path, "# Plan\n\n日本語の説明です。\n")

      stdout, _stderr, status = Open3.capture3(SCRIPT, path)

      assert_equal 1, status.exitstatus
      assert_includes stdout, "#{path}:3"
    end
  end

  def test_accepts_a_documented_next_line_exception
    Dir.mktmpdir do |directory|
      path = File.join(directory, "glossary.md")
      File.write(
        path,
        "<!-- repository-language: allow-next-line reason=localized-gloss -->\n- Japanese: 日本語\n",
      )

      _stdout, stderr, status = Open3.capture3(SCRIPT, path)

      assert_predicate status, :success?, stderr
    end
  end

  def test_rejects_an_exception_without_a_reason
    Dir.mktmpdir do |directory|
      path = File.join(directory, "glossary.md")
      File.write(path, "<!-- repository-language: allow-next-line -->\n- Japanese: 日本語\n")

      stdout, _stderr, status = Open3.capture3(SCRIPT, path)

      assert_equal 2, status.exitstatus
      assert_includes stdout, "exception requires a reason"
    end
  end

  def test_checks_japanese_source_comments_but_ignores_localized_string_literals
    Dir.mktmpdir do |directory|
      path = File.join(directory, "example.rb")
      File.write(path, "MESSAGE = \"日本語\"\n# 日本語のコメント\n")

      stdout, _stderr, status = Open3.capture3(SCRIPT, path)

      assert_equal 1, status.exitstatus
      assert_includes stdout, "#{path}:2"
      # Plain Minitest does not provide Rails' assert_not_includes assertion.
      # rubocop:disable Rails/RefuteMethods
      refute_includes stdout, "#{path}:1"
      # rubocop:enable Rails/RefuteMethods
    end
  end

  def test_checks_japanese_test_names_but_ignores_localized_assertions
    Dir.mktmpdir do |directory|
      path = File.join(directory, "example_test.rb")
      File.write(path, "test \"日本語の名前\" do\n  assert_equal \"日本語\", value\nend\n")

      stdout, _stderr, status = Open3.capture3(SCRIPT, path)

      assert_equal 1, status.exitstatus
      assert_includes stdout, "#{path}:1"
      # Plain Minitest does not provide Rails' assert_not_includes assertion.
      # rubocop:disable Rails/RefuteMethods
      refute_includes stdout, "#{path}:2"
      # rubocop:enable Rails/RefuteMethods
    end
  end
end

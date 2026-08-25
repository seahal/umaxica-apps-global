# typed: false
# frozen_string_literal: true

# rubocop:disable I18n/RailsI18n/DecorateString

require "test_helper"

# A template with unbalanced ERB blocks raises SyntaxError only when the action
# that renders it is exercised. Two account-recovery templates shipped broken
# because no request test covered their routes, and Brakeman silently skipped
# both files rather than analysing them - a template it cannot parse is excluded
# from every one of its security checks.
#
# This compiles every template with the same Erubi engine ActionView uses at
# runtime, so a structural break fails here instead of in production.
class TemplateCompilationTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "every ERB template compiles" do
    engine = ActionView::Template::Handlers::ERB::Erubi
    template_paths = Rails.root.glob("app/views/**/*.erb")

    assert_operator template_paths.size, :>, 0, "No ERB templates found - the glob is wrong."

    failures =
      template_paths.filter_map do |path|
        source = engine.new(File.read(path), bufvar: "@output_buffer", trim: true).src
        # Wrap in a method so `local_assigns`, `output_buffer`, and `yield` resolve
        # the same way ActionView compiles them.
        RubyVM::InstructionSequence.compile("def __compile_check(local_assigns, output_buffer); #{source}; end")
        nil
      rescue SyntaxError => e
        relative = path.to_s.sub("#{Rails.root.join}", "")
        "#{relative}: #{e.message.lines.first.to_s.strip}"
      end

    assert_empty failures,
                 "ERB templates that do not compile (they raise SyntaxError when rendered, " \
                 "and Brakeman skips them entirely):\n  #{failures.join("\n  ")}"
  end
end

# rubocop:enable I18n/RailsI18n/DecorateString

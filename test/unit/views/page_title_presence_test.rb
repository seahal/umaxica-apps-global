# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class PageTitlePresenceTest < ActiveSupport::TestCase
  # Pure static analysis test - no database/fixtures needed
  self.use_transactional_tests = false
  self.fixture_table_names = []

  # Patterns that indicate a page title is set
  PAGE_TITLE_PATTERNS = [
    /content_for\s+:page_title/,
    /provide\s*\(\s*:page_title/,
    /page_title\s+/, # ApplicationHelper#page_title
    /<%=?\s*title\s+/, # meta-tags gem helper
    /set_meta_tags.*title/,
    %r{<title[^>]*>},  # standalone full-page views that own their own <title> tag
    /display_meta_tags/, # standalone full-page views rendering their title through meta-tags
  ].freeze

  # Files excluded from page_title requirement with reasons
  EXCLUDED_PATHS = [
    # Email/mailer views: rendered inside mailer layouts (separate title mechanism)
    %r{^/app/views/email/},
    # Layouts are not "page views"
    %r{^/app/views/layouts/},
  ].freeze

  test "all non-partial views have a page_title declaration" do
    view_root = Rails.root.join("app/views")
    view_files = Dir.glob(view_root.join("**", "*.html.erb"))

    # Filter to non-partial, non-layout views
    page_views =
      view_files.reject do |path|
        relative = path.to_s.sub("#{Rails.root}", "")
        File.basename(path).start_with?("_") || # partials
          EXCLUDED_PATHS.any? { |pat| relative.match?(pat) }
      end

    missing = []
    page_views.each do |path|
      content = File.read(path)
      has_title = PAGE_TITLE_PATTERNS.any? { |pat| content.match?(pat) }
      relative = path.sub("#{Rails.root.join}", "")
      missing << relative unless has_title
    end

    assert_empty missing,
                 "#{missing.size} view(s) missing page_title declaration:\n  #{missing.join("\n  ")}"
  end
end

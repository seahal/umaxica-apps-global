# typed: false
# frozen_string_literal: true

require "test_helper"

class LayoutTitleContractTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  CANONICAL_LAYOUTS = {
    "app/views/layouts/auth/app/application.html.erb" => '#{ENV.fetch("BRAND_NAME")} (app) Auth',
    "app/views/layouts/auth/com/application.html.erb" => '#{ENV.fetch("BRAND_NAME")} (com) Auth',
    "app/views/layouts/auth/org/application.html.erb" => '#{ENV.fetch("BRAND_NAME")} (org) Auth',
    "app/views/layouts/base/app/application.html.erb" => '#{ENV.fetch("BRAND_NAME")} (app) Base',
    "app/views/layouts/base/com/application.html.erb" => '#{ENV.fetch("BRAND_NAME")} (com) Base',
    "app/views/layouts/base/org/application.html.erb" => '#{ENV.fetch("BRAND_NAME")} (org) Base',
    "app/views/layouts/core/app/application.html.erb" => '#{ENV.fetch("BRAND_NAME")} (app) Core',
    "app/views/layouts/core/com/application.html.erb" => '#{ENV.fetch("BRAND_NAME")} (com) Core',
    "app/views/layouts/core/org/application.html.erb" => '#{ENV.fetch("BRAND_NAME")} (org) Core',
    "app/views/layouts/side/app/application.html.erb" => '#{ENV.fetch("BRAND_NAME")} (app) Side',
    "app/views/layouts/side/com/application.html.erb" => '#{ENV.fetch("BRAND_NAME")} (com) Side',
    "app/views/layouts/side/org/application.html.erb" => '#{ENV.fetch("BRAND_NAME")} (org) Side',
    "app/views/layouts/palm/app/application.html.erb" => '#{ENV.fetch("BRAND_NAME")} (app) Palm',
  }.freeze

  test "canonical layout files declare the literal title site suffix" do
    CANONICAL_LAYOUTS.each do |path, title_site|
      contents = Rails.root.join(path).read

      assert_predicate Rails.root.join(path), :exist?
      assert_includes contents, %(title_site = "#{title_site}"), "missing literal title_site in #{path}"
      assert_includes contents, "display_meta_tags site: title_site, title: page_title",
                      "missing display_meta_tags contract in #{path}"
      assert_not_includes contents, "content_for", "layout #{path} must not use content_for"
      assert_not_includes contents, "yield :", "layout #{path} must not use named yield"
      assert_not_includes contents, "surface =", "layout #{path} must not define a surface variable"
      assert_not_includes contents, "tld =", "layout #{path} must not define a tld variable"
      assert_not_includes contents, "vite_entrypoint =", "layout #{path} must not define a vite entrypoint variable"
      refute_match(/\b\w+_path\s*=\s*/, contents, "layout #{path} must not precompute route helpers")
      refute_match(/title_site\s*=\s*".*#\{[^}]*\b(surface|tld)\b[^}]*\}/, contents,
                   "layout #{path} must not derive title_site from surface/tld variables")
    end
  end

  test "canonical layout roots remain constrained to the current surfaces" do
    assert_predicate Rails.root.join("app/views/layouts/palm/app/application.html.erb"), :exist?
    assert_not_predicate Rails.root.join("app/views/layouts/palm/com"), :exist?
    assert_not_predicate Rails.root.join("app/views/layouts/palm/org"), :exist?

    %w(acme sign apex).each do |legacy_root|
      assert_empty Dir.glob(Rails.root.join("app/views/layouts/#{legacy_root}/**/*"))
    end
  end
end

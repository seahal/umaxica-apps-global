# typed: false
# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "pathname"
require "yaml"

class FrontendStackIsolationTest < Minitest::Test
  ROOT = Pathname.new(__dir__).join("../..").expand_path
  MAPPING = YAML.load_file(ROOT.join("config/frontend_stacks.yml"), aliases: false)

  def test_mapping_covers_every_application_layout
    mapped = MAPPING.fetch("stacks").except("excluded").values.flatten
    excluded = MAPPING.fetch("stacks").fetch("excluded", [])
    layouts =
      Dir[ROOT.join("app/views/layouts/**/*application.html.erb")].map { |path|
        path.delete_prefix(ROOT.join("app/views/layouts/").to_s).delete_suffix(".html.erb")
      }

    assert_equal layouts.sort, (mapped.grep(/application\z/) + excluded).sort
    assert_equal mapped.uniq.size, mapped.size
  end

  def test_importmap_and_vite_layouts_are_isolated
    MAPPING.fetch("stacks").fetch("importmap").each do |surface|
      html = ROOT.join("app/views/layouts", "#{surface}.html.erb").read

      assert_includes html, "javascript_importmap_tags", surface
      assert_not_includes html, "vite_", surface
      assert_not_includes html, "inertia_root", surface
    end
    MAPPING.fetch("stacks").fetch("vite").grep(/inertia\z/).each do |surface|
      html = ROOT.join("app/views/layouts", "#{surface}.html.erb").read

      assert_includes html, "vite_typescript_tag", surface
      assert_includes html, "inertia_root", surface
      assert_not_includes html, "javascript_importmap_tags", surface
    end
  end

  def test_vite_content_templates_stay_vite_only
    MAPPING.fetch("stacks").fetch("vite").grep(/root\z/).each do |surface|
      path = ROOT.join("app/views", "#{surface.sub(%r{/root\z}, "/roots/index")}.html.erb")
      html = path.read

      assert_includes html, "vite_stylesheet_tag", surface
      assert_not_includes html, "javascript_importmap_tags", surface
    end
  end

  def test_both_stacks_have_csp_nonces_and_separate_css_ownership
    Dir[ROOT.join("app/views/layouts/**/*application.html.erb")].each { |path|
      assert_includes File.read(path), "nonce: true" unless path.end_with?("email/application.html.erb")
    }

    Dir[ROOT.join("app/views/layouts/**/*inertia.html.erb")].each { |path|
      assert_includes File.read(path), "nonce: true"
    }
    assert_predicate ROOT.join("app/assets/stylesheets/application.css"), :exist?
    assert_predicate ROOT.join("src/styles/surfaces"), :directory?
  end
end

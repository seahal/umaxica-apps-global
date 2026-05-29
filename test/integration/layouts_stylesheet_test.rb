# typed: false
# frozen_string_literal: true

require "test_helper"

class StylesheetTagsTest < ActiveSupport::TestCase
  IMPORTMAP_LAYOUT_PATHS = [
    "app/views/layouts/acme/app/application.html.erb",
    "app/views/layouts/acme/com/application.html.erb",
    "app/views/layouts/acme/org/application.html.erb",
    "app/views/layouts/sign/app/application.html.erb",
    "app/views/layouts/sign/com/application.html.erb",
    "app/views/layouts/sign/org/application.html.erb",
  ].freeze

  test "sign layouts include sign main stylesheet" do
    paths = [
      "app/views/layouts/sign/app/application.html.erb",
      "app/views/layouts/sign/com/application.html.erb",
      "app/views/layouts/sign/org/application.html.erb",
    ]

    paths.each do |path|
      contents = Rails.root.join(path).read

      assert_match(
        /(stylesheet_link_tag\s+\"sign\/main\")|(\"sign\/main\")/, contents,
        "missing sign/main in #{path}",
      )
    end
  end

  test "acme layouts include acme main stylesheet" do
    paths = [
      "app/views/layouts/acme/app/application.html.erb",
      "app/views/layouts/acme/com/application.html.erb",
      "app/views/layouts/acme/org/application.html.erb",
    ]

    paths.each do |path|
      contents = Rails.root.join(path).read

      assert_match(
        /(stylesheet_link_tag\s+\"acme\/main\")|(\"acme\/main\")/, contents,
        "missing acme/main in #{path}",
      )
    end
  end

  test "importmap layouts expose csp nonce for turbo head script rendering" do
    IMPORTMAP_LAYOUT_PATHS.each do |path|
      contents = Rails.root.join(path).read

      assert_includes contents, "csp_meta_tag", "missing csp_meta_tag in #{path}"
      assert_operator(
        contents.index("csp_meta_tag"),
        :<,
        contents.index("javascript_importmap_tags"),
        "csp_meta_tag must appear before javascript_importmap_tags in #{path}",
      )
    end
  end
end

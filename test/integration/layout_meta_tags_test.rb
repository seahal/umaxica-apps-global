# typed: false
# frozen_string_literal: true

require "test_helper"

class LayoutMetaTagsTest < ActiveSupport::TestCase
  LAYOUT_PATHS = {
    "Base::App" => "app/views/layouts/acme/app/application.html.erb",
    "Base::App::Inertia" => "app/views/layouts/base/app/inertia.html.erb",
    "Base::Com" => "app/views/layouts/acme/com/application.html.erb",
    "Base::Org" => "app/views/layouts/acme/org/application.html.erb",
    "Sign::App" => "app/views/layouts/sign/app/application.html.erb",
    "Sign::Com" => "app/views/layouts/sign/com/application.html.erb",
    "Sign::Org" => "app/views/layouts/sign/org/application.html.erb",
  }.freeze

  test "all layouts include turbo-refresh-scroll meta tag" do
    LAYOUT_PATHS.each do |name, path|
      content = Rails.root.join(path).read

      assert_match(
        /turbo-refresh-scroll/, content,
        "Expected turbo-refresh-scroll meta tag in #{name} layout (#{path})",
      )
    end
  end

  test "all layouts include title tag" do
    LAYOUT_PATHS.each do |name, path|
      content = Rails.root.join(path).read

      assert_match(
        /display_meta_tags|<title>/, content,
        "Expected title tag in #{name} layout (#{path})",
      )
    end
  end

  test "inertia layout includes lang and theme markers" do
    content = Rails.root.join("app/views/layouts/base/app/inertia.html.erb").read

    assert_includes content, 'lang="<%= get_language %>"'
    assert_includes content, 'data-theme="<%= theme_cookie_value %>"'
    assert_includes content, 'class="<%= theme_html_class %>"'
    assert_includes content, "page_title(page&.dig(:props, :title))"
  end
end

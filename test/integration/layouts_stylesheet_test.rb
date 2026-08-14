# typed: false
# frozen_string_literal: true

require "test_helper"

class StylesheetTagsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  APPLICATION_LAYOUTS = {
    "app/views/layouts/base/app/application.html.erb" => "entrypoints/base/app",
    "app/views/layouts/base/com/application.html.erb" => "entrypoints/base/com",
    "app/views/layouts/base/org/application.html.erb" => "entrypoints/base/org",
    "app/views/layouts/auth/app/application.html.erb" => "entrypoints/sign/app",
    "app/views/layouts/auth/com/application.html.erb" => "entrypoints/sign/com",
    "app/views/layouts/auth/org/application.html.erb" => "entrypoints/sign/org",
  }.freeze

  # One Inertia layout per user-facing FQDN, each loading only its own surface entrypoint.
  INERTIA_LAYOUTS = %w(
    base/app base/com base/org
    auth/app auth/com auth/org
    side/app side/com side/org
    palm/app
  ).to_h do |surface|
    family, boundary = surface.split("/")
    ["app/views/layouts/#{surface}/inertia.html.erb", "entrypoints/inertia/#{family}_#{boundary}.tsx"]
  end.freeze

  TURNSTILE_LAYOUTS = %w(
    app/views/layouts/base/app/application.html.erb
    app/views/layouts/base/com/application.html.erb
    app/views/layouts/base/org/application.html.erb
    app/views/layouts/auth/app/application.html.erb
    app/views/layouts/auth/com/application.html.erb
    app/views/layouts/auth/org/application.html.erb
  ).freeze

  FORBIDDEN_TAILWIND_FRAGMENTS = %w(
    bg-
    border-
    flex
    font-
    gap-
    inset-
    justify-
    min-h-screen
    opacity-
    p-
    rounded
    shadow
    space-
    text-
    hover:
  ).freeze

  test "target layouts use Vite and avoid stylesheet_link_tag" do
    APPLICATION_LAYOUTS.merge(INERTIA_LAYOUTS).each do |path, entrypoint|
      contents = Rails.root.join(path).read

      assert_includes contents, "<meta charset=\"utf-8\">", "missing charset meta tag in #{path}"
      assert_includes contents, "display_meta_tags", "missing title metadata helper in #{path}"
      assert_includes contents, 'meta name="turbo-refresh-method" content="morph"',
                      "missing turbo refresh method meta tag in #{path}"
      assert_includes contents, 'meta name="turbo-refresh-scroll" content="preserve"',
                      "missing turbo refresh scroll meta tag in #{path}"
      assert_includes contents, %(vite_typescript_tag "#{entrypoint}"),
                      "missing Vite entrypoint in #{path}"
      assert_not_includes contents, "stylesheet_link_tag",
                          "layout #{path} must reach Vite CSS through vite_stylesheet_tag, not Sprockets"
      assert_not_includes contents, "content_for", "layout #{path} must not use content_for"
      assert_not_includes contents, "yield :head", "layout #{path} must not use named head yields"
      assert_not_includes contents, "yield :nav_links", "layout #{path} must not use named nav yields"
      assert_not_includes contents, "yield :root_link", "layout #{path} must not use named root yields"
      assert_not_includes contents, "yield :footer_links", "layout #{path} must not use named footer yields"
      assert_not_includes contents, "t(..., default:", "layout #{path} must not use i18n defaults"
      assert_not_includes contents, "surface =", "layout #{path} must not define a surface variable"
      assert_not_includes contents, "tld =", "layout #{path} must not define a tld variable"
      assert_not_includes contents, "vite_entrypoint =", "layout #{path} must not define a vite entrypoint variable"
      assert_no_match(/\b\w+_path\s*=/, contents, "layout #{path} must not precompute route helpers")
      assert_no_match(
        /class="[^"]*(?:#{FORBIDDEN_TAILWIND_FRAGMENTS.join("|")})[^"]*"/,
        contents,
        "layout #{path} must not carry Tailwind utility classes",
      )
    end
  end

  test "target layouts include shared chrome and semantic landmarks" do
    APPLICATION_LAYOUTS.each_key do |path|
      contents = Rails.root.join(path).read

      assert_includes contents, "<header>", "layout #{path} must include a header"
      assert_includes contents, "<nav aria-label=", "layout #{path} must label navigation"
      assert_includes contents, 'id="main"', "layout #{path} must place content in main#main"
      assert_includes contents, "<footer>", "layout #{path} must include a footer"
      assert_includes contents, 'render "layouts/shared/flash_messages"', "layout #{path} must render flash messages"
      assert_includes contents, 'render "layouts/shared/current_banner"', "layout #{path} must render the banner"
      assert_includes contents, 'render "layouts/shared/footer_cookie_controls"',
                      "layout #{path} must render cookie controls"
      assert_includes contents, 'render "layouts/shared/footer_theme_controls"',
                      "layout #{path} must render theme controls"
      assert_includes contents, 'render "layouts/shared/copyright"',
                      "layout #{path} must render copyright"
    end
  end

  test "sign and base application layouts own turnstile api loading" do
    TURNSTILE_LAYOUTS.each do |path|
      contents = Rails.root.join(path).read

      assert_includes contents, 'render "layouts/shared/cloudflare_turnstile_api"',
                      "Turnstile API loading must be layout-owned in #{path}"
    end
  end

  test "application-owned importmap entrypoints are retired" do
    assert_not Rails.root.join("config/importmap.rb").exist?, "config/importmap.rb must not be restored"
    assert_not Rails.root.join("bin/importmap").exist?, "bin/importmap must not be restored"

    gemfile = Rails.root.join("Gemfile").read

    assert_no_match(/^\s*gem\s+["']importmap-rails["']/, gemfile)
  end

  test "every inertia layout loads its own surface entrypoint and no other" do
    INERTIA_LAYOUTS.each do |path, entrypoint|
      contents = Rails.root.join(path).read
      foreign = INERTIA_LAYOUTS.values - [entrypoint]

      assert_includes contents, 'meta name="turbo-refresh-method" content="morph"'
      assert_includes contents, 'meta name="turbo-refresh-scroll" content="preserve"'
      assert_includes contents, %(vite_typescript_tag "#{entrypoint}")
      # A stylesheet reached through the entrypoint's JavaScript is dropped by
      # `ViteRuby::Manifest#resolve_entries` while the dev server runs, so it cannot style the first
      # paint. The link has to be in the layout to block rendering in every environment.
      family, surface = path.delete_prefix("app/views/layouts/").split("/").first(2)

      assert_includes contents, %(vite_stylesheet_tag "~/styles/surfaces/#{family}_#{surface}.css"),
                      "layout #{path} must link its own surface stylesheet"
      assert_includes contents, "inertia_root", "layout #{path} must render the Inertia root element"
      assert_not_includes contents, "yield", "layout #{path} renders the page through Inertia, not a yield"

      foreign.each do |other|
        assert_not_includes contents, other, "layout #{path} must not load another surface's entrypoint"
      end
    end
  end
end

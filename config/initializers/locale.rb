# typed: false
# frozen_string_literal: true

require "i18n/backend/fallbacks"

# Allow english requests to transparently reuse japanese strings until proper
# translations are added.
I18n::Backend::Simple.include I18n::Backend::Fallbacks

region_code = ENV.fetch("REGION_CODE") # REGION_CODE is required, no default value
locale_root = Rails.root.join("config/locales")

# "all" is a virtual region that combines jp + us (us takes priority over jp).
# Other region codes map directly to a directory under config/locales/.
REGION_COMPOSE = { "all" => %w(jp us) }.freeze
region_dirs =
  if REGION_COMPOSE.key?(region_code)
    REGION_COMPOSE[region_code].map { |code| locale_root.join(code) }
  else
    [locale_root.join(region_code)]
  end

region_dirs.each do |dir|
  next if dir.directory?

  raise ArgumentError,
        "REGION_CODE='#{region_code}' is invalid. Directory not found: #{dir}. " \
        "Valid values are: #{locale_root.children.filter_map { |child|
          child.basename if child.directory?
        }.join(", ")}, all"
end

# Collect region locale files in priority order (later entries win in i18n).
# Keep locale file order deterministic so reloading the initializer in tests
# cannot let previous REGION_CODE values keep stale files in the load path.
region_locale_files = region_dirs.flat_map { |dir| Dir[dir.join("**", "*.{rb,yml}")] }

# Identify all region files, including the currently selected region, so reloads
# can replace the regional portion of the load path atomically.
all_region_dirs = locale_root.children.select(&:directory?)
all_region_files = all_region_dirs.flat_map { |dir| Dir[dir.join("**", "*.{rb,yml}")] }.map(&:to_s)

I18n.load_path.reject! { |path| all_region_files.include?(path.to_s) }
I18n.load_path += region_locale_files
I18n.load_path.uniq!

I18n.load_path += Rails.root.glob("lib/locale/*.{rb,yml}")
I18n.available_locales = [:en, :ja]
I18n.default_locale = :ja
I18n.fallbacks = { en: [:en, :ja], ja: [:ja, :en] }
I18n.backend.reload!

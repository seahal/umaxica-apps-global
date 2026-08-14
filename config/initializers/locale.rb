# typed: false
# frozen_string_literal: true

require "i18n/backend/fallbacks"

# Allow english requests to transparently reuse japanese strings until proper
# translations are added.
I18n::Backend::Simple.include I18n::Backend::Fallbacks

# Load every bundle under config/locales, deepest paths last so region-specific files deep-merge
# over the shared ones. A literal file list silently drops any bundle added later, which surfaces as
# a missing translation at runtime instead of a boot failure.
locale_root = Rails.root.join("config/locales")
# Sorted so deep-merge precedence between bundles does not depend on filesystem enumeration order.
locale_files = Dir[locale_root.join("**", "*.yml")].sort_by(&:to_s)

if locale_files.empty?
  raise RuntimeError, "No locale bundles found under #{locale_root}"
end

I18n.load_path =
  I18n.load_path.reject { |path| path.to_s.start_with?(locale_root.to_s) } + locale_files

I18n.available_locales = [:en, :ja]
I18n.default_locale = :ja
I18n.fallbacks = I18n::Locale::Fallbacks.new(en: [:en, :ja], ja: [:ja, :en])
I18n.backend.reload!

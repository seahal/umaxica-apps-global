# typed: false
# frozen_string_literal: true

require "i18n/backend/fallbacks"

# Allow english requests to transparently reuse japanese strings until proper
# translations are added.
I18n::Backend::Simple.include I18n::Backend::Fallbacks

locale_files =
  %w(
    config/locales/jp/en.yml
    config/locales/jp/ja.yml
    config/locales/us/en.yml
    config/locales/us/ja.yml
  ).map { |path| Rails.root.join(path).to_s }
locale_roots = [
  Rails.root.join("config/locales").to_s,
  Rails.root.join("lib/locale").to_s,
]

I18n.load_path =
  I18n.load_path.reject do |path|
    locale_roots.any? { |root| path.to_s.start_with?(root) }
  end
I18n.load_path += locale_files

I18n.available_locales = [:en, :ja]
I18n.default_locale = :ja
I18n.fallbacks = { en: [:en, :ja], ja: [:ja, :en] }
I18n.backend.reload!

# typed: false
# frozen_string_literal: true

require "i18n/backend/fallbacks"

# Allow english requests to transparently reuse japanese strings until proper
# translations are added.
I18n::Backend::Simple.include I18n::Backend::Fallbacks

locale_root = Rails.root.join("config/locales")
locale_files = Dir[locale_root.join("**", "*.{rb,yml}")]

I18n.load_path += locale_files
I18n.load_path.uniq!

I18n.load_path += Rails.root.glob("lib/locale/*.{rb,yml}")
I18n.available_locales = [:en, :ja]
I18n.default_locale = :ja
I18n.fallbacks = { en: [:en, :ja], ja: [:ja, :en] }
I18n.backend.reload!

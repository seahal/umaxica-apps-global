# typed: false
# frozen_string_literal: true

module Preference
  # Tracks which preference fields the user set explicitly.
  #
  # Child preference records (language, region, ...) are always created with a
  # default option on first visit, so a child's presence or value cannot tell
  # an explicit choice apart from an auto-seeded default. The `explicit_fields`
  # jsonb column records the field names the user changed on purpose. This drives
  # localization: an explicitly set language wins over dynamic region seeding
  # (?ri), while an unset (default-only) field stays eligible for seeding.
  module ExplicitFields
    extend ActiveSupport::Concern

    def explicit_field?(field)
      explicit_field_names.include?(field.to_s)
    end

    def explicit_field_names
      Array(explicit_fields).map(&:to_s)
    end

    def mark_field_explicit!(field)
      normalized = field.to_s
      names = explicit_field_names
      return if names.include?(normalized)

      update!(explicit_fields: (names + [normalized]).uniq)
    end

    def clear_explicit_fields!
      return if explicit_field_names.empty?

      update!(explicit_fields: [])
    end
  end
end

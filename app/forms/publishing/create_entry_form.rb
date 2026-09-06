# typed: false
# frozen_string_literal: true

module Publishing
  # Input for a new staff CMS entry: the shared content fields plus the two
  # values that exist only at creation.
  #
  # `locale` is fixed when the entry is created -- a translation is a separate
  # entry in this schema, not a field on this one -- and `slug` is the path
  # segment the published URL resolves on. Both are checked against the same
  # rules the database enforces (`chk_<cell>_slug_format`, and the locale set
  # the taxonomy snapshot checks pin), so a rejected value is named on the
  # form instead of raised from PostgreSQL.
  class CreateEntryForm < EntryContentForm
    SLUG_FORMAT = /\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/

    attribute :locale, :string
    attribute :slug, :string

    validates :locale, inclusion: { in: -> (_form) { I18n.available_locales.map(&:to_s) } }
    validates :slug, presence: true, format: { with: SLUG_FORMAT, allow_blank: true }

    private

    def message_for(attribute, error)
      if attribute == :locale && error == :inclusion
        "must be one of #{I18n.available_locales.map(&:to_s).join(', ')}"
      elsif attribute == :slug && error == :blank
        "can't be blank"
      elsif attribute == :slug && error == :invalid
        "must be lowercase letters, digits, and hyphens"
      else
        super
      end
    end
  end
end

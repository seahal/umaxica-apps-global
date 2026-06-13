# typed: false
# frozen_string_literal: true

module ReadOnlyContentEntry
  extend ActiveSupport::Concern

  STATUSES = %w[draft published archived].freeze
  SLUG_FORMAT = /\A[a-z0-9]+(?:[a-z0-9-]*[a-z0-9])?\z/

  included do
    validates :slug, presence: true, format: { with: SLUG_FORMAT }
    validates :locale, presence: true
    validates :title, presence: true
    validates :body, presence: true
    validates :status, presence: true, inclusion: { in: STATUSES }
    validates :slug, uniqueness: { scope: :locale }

    scope :published, -> { where(status: "published").where(arel_table[:published_at].lteq(Time.current)) }
    scope :for_locale, ->(locale) { where(locale: locale.to_s) }
    scope :recent_first, -> { order(published_at: :desc, id: :desc) }
  end

  def published?
    status == "published" && published_at.present? && published_at <= Time.current
  end

  def as_public_json(namespace:, surface:)
    {
      namespace: namespace.to_s,
      surface: surface.to_s,
      slug: slug,
      locale: locale,
      title: title,
      summary: summary,
      body: body,
      published_at: published_at&.iso8601,
    }
  end
end

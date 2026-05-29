# typed: false
# frozen_string_literal: true

module PublisherPostDocument
  extend ActiveSupport::Concern

  RESPONSE_MODES = %w(html text pdf redirect).freeze

  included do
    enum :response_mode, {
      html: "html",
      text: "text",
      pdf: "pdf",
      redirect: "redirect",
    }, suffix: true, validate: true

    before_validation :ensure_revision_key
    before_validation :ensure_permalink
    before_validation :ensure_publication_window

    validates :permalink, presence: true, uniqueness: true, length: { maximum: 200 },
                          format: { with: /\A[A-Za-z0-9_][A-Za-z0-9_-]{0,199}\z/ }
    validates :response_mode, presence: true
    validates :revision_key, presence: true
    validates :published_at, presence: true
    validates :expires_at, presence: true
    validates :redirect_url, presence: true, if: :redirect_response_mode?

    validate :published_at_before_expires_at
    validate :response_mode_columns_are_consistent

    scope :available, -> {
      now = Time.current
      where("#{table_name}.published_at <= ? AND #{table_name}.expires_at > ?", now, now)
    }
  end

  private

  def ensure_revision_key
    self.revision_key = SecureRandom.urlsafe_base64(32) if revision_key.blank?
  end

  def ensure_permalink
    self.permalink = public_id if permalink.blank? && public_id.present?
  end

  def ensure_publication_window
    self.published_at ||= Time.current
    self.expires_at ||= 100.years.from_now
  end

  def published_at_before_expires_at
    return if published_at.blank? || expires_at.blank?
    return if published_at < expires_at

    errors.add(:published_at, "must be before expires_at")
  end

  def response_mode_columns_are_consistent
    return if response_mode != "redirect"
    return if redirect_url.present?

    errors.add(:redirect_url, "must be present for redirect response mode")
  end
end

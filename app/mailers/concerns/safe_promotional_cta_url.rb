# typed: false
# frozen_string_literal: true

module SafePromotionalCtaUrl
  extend ActiveSupport::Concern

  private

  def safe_promotional_cta_url(value)
    raw = value.to_s.strip
    return nil if raw.blank?
    return nil if raw.match?(/[\x00-\x1F\x7F]/)

    uri = URI.parse(raw)
    return nil unless uri.is_a?(URI::HTTP)
    return nil unless uri.scheme == "https"
    return nil if uri.host.blank?
    return nil if uri.userinfo.present?

    uri.scheme = uri.scheme.downcase
    uri.host = uri.host.downcase
    uri.to_s
  rescue URI::InvalidURIError
    nil
  end
end

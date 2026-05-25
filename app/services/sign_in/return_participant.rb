# typed: false
# frozen_string_literal: true

module SignIn
  class ReturnParticipant
    attr_reader :cycle, :default_path

    def initialize(cycle:, default_path:)
      @cycle = cycle
      @default_path = default_path
    end

    def consume!
      cycle.class.transaction do
        cycle.lock!

        destination = safe_return_path(cycle.return_to) || default_path
        cycle.update!(return_to: nil) if cycle.return_to.present?
        cycle.complete_sign_in!

        destination
      end
    end

    private

    def safe_return_path(value)
      raw = value.to_s
      return nil if raw.blank?
      return nil if raw.match?(/[\x00-\x1F\x7F]/)
      return nil if raw.match?(/%(?:0[0-9a-f]|1[0-9a-f]|7f)/i)
      return nil if raw.match?(/%(?:2f|5c)/i)
      return nil if raw.include?("\\")
      return nil unless raw.start_with?("/")
      return nil if raw.start_with?("//")

      uri = URI.parse(raw)
      return nil if uri.scheme.present? || uri.host.present? || uri.userinfo.present?
      return nil if uri.fragment.present?

      path = uri.path
      return nil if path.blank?

      query = uri.query.present? ? "?#{uri.query}" : ""
      "#{path}#{query}"
    rescue URI::InvalidURIError
      nil
    end
  end
end

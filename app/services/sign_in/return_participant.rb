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
      return nil unless raw.start_with?("/")
      return nil if raw.start_with?("//")
      return nil if raw.match?(/[\r\n]/)

      uri = URI.parse(raw)
      return nil if uri.scheme.present? || uri.host.present? || uri.userinfo.present?

      path = uri.path.presence || "/"
      query = uri.query.present? ? "?#{uri.query}" : ""
      "#{path}#{query}"
    rescue URI::InvalidURIError
      nil
    end
  end
end

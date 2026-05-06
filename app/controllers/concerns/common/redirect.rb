# typed: false
# frozen_string_literal: true

module Common
  module Redirect
    extend ActiveSupport::Concern

    def self.normalize_host(val)
      return nil if val.blank?

      str = val.to_s.strip
      begin
        uri = URI.parse(str)
        host = uri.host.presence || str.split("/").first
      rescue URI::InvalidURIError
        host = str
      end
      # strip scheme remnants and spaces
      host.to_s.downcase.sub(%r{^https?://}i, "").split("/").first
    end

    def allowed_hosts
      # NOTE: External redirect is disabled. This list remains only for diagnostics/auditing.
      keys = %w(CORPORATE_URL SERVICE_URL STAFF_URL NETWORK_URL DEV_URL)
      keys.filter_map { |k| Common::Redirect.normalize_host(ENV[k]) }
    end

    private

    def safe_redirect_to(target, fallback: "/", **)
      safe_path = safe_internal_path(target)

      if safe_path
        redirect_to(safe_path, allow_other_host: false, **)
      else
        redirect_to(fallback, allow_other_host: false, **)
      end
    end

    def safe_redirect_back_or_to(fallback, **)
      safe_path = safe_internal_path(request.referer)
      redirect_to(safe_path || fallback, allow_other_host: false, **)
    end

    def safe_internal_path(target)
      return nil if target.blank?
      return nil if target.match?(/[[:cntrl:]]/)

      begin
        parsed_uri = URI.parse(target)
      rescue URI::InvalidURIError
        return nil
      end

      return nil if parsed_uri.scheme.present? || parsed_uri.host.present?
      return nil if parsed_uri.user.present? || parsed_uri.password.present?

      path = parsed_uri.path.presence || "/"
      return nil unless path.start_with?("/")

      query = parsed_uri.query
      query.present? ? "#{path}?#{query}" : path
    end

    def generate_redirect_url(url)
      safe_path = safe_internal_path(url)

      return unless safe_path

      Base64.urlsafe_encode64(safe_path, padding: false)
    end

    def jump_to_generated_url(encoded_url, fallback: "/")
      return redirect_to(fallback) if encoded_url.blank?

      begin
        decoded_url = Base64.urlsafe_decode64(encoded_url)
        safe_redirect_to(decoded_url, fallback: fallback)
      rescue ArgumentError, URI::InvalidURIError => e
        Rails.event.notify("redirect.invalid_url", error_message: e.message)
        redirect_to(fallback)
      end
    end
  end
end

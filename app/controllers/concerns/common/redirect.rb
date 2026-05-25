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
      return nil unless target.is_a?(String)
      return nil if target.blank?
      return nil if target.match?(/[\x00-\x1F\x7F]/)
      return nil if target.match?(/%(?:0[0-9a-f]|1[0-9a-f]|7f)/i)
      return nil if target.match?(/%(?:2f|5c)/i)
      return nil if target.include?("\\")

      begin
        parsed_uri = URI.parse(target)
      rescue URI::InvalidURIError
        return nil
      end

      return nil if parsed_uri.scheme.present? || parsed_uri.host.present?
      return nil if parsed_uri.userinfo.present?
      return nil if parsed_uri.fragment.present?

      path = parsed_uri.path
      return nil if path.blank?
      return nil unless path.start_with?("/")
      return nil if path.start_with?("//")

      query = parsed_uri.query
      query.present? ? "#{path}?#{query}" : path
    end

    def safe_return_path(target, allowed_hosts: nil)
      return nil unless target.is_a?(String)
      return nil if target.blank?
      return nil if target.match?(/[\x00-\x1F\x7F]/)
      return nil if target.match?(/%(?:0[0-9a-f]|1[0-9a-f]|7f)/i)
      return nil if target.match?(/%(?:2f|5c)/i)
      return nil if target.include?("\\")

      begin
        parsed_uri = URI.parse(target)
      rescue URI::InvalidURIError
        return nil
      end

      return nil if parsed_uri.user.present? || parsed_uri.password.present?
      return nil if parsed_uri.fragment.present?

      return safe_internal_path(target) unless parsed_uri.scheme.present? || parsed_uri.host.present?
      return nil unless %w(http https).include?(parsed_uri.scheme)
      return nil unless allowed_return_hosts(allowed_hosts).include?(host_with_optional_port(parsed_uri))

      path = parsed_uri.path.presence || "/"
      return nil unless path.start_with?("/")

      query = parsed_uri.query
      query.present? ? "#{path}?#{query}" : path
    end

    def generate_redirect_url(url)
      safe_path = safe_return_path(url)

      return unless safe_path

      Base64.urlsafe_encode64(safe_path, padding: false)
    end

    def jump_to_generated_url(encoded_url, fallback: "/")
      return redirect_to(fallback) if encoded_url.blank?

      begin
        decoded_url = Base64.urlsafe_decode64(encoded_url)
        safe_path = safe_return_path(decoded_url)
        redirect_to(safe_path || fallback, allow_other_host: false)
      rescue ArgumentError, URI::InvalidURIError => e
        Rails.logger.info(LogEvent.format("redirect.invalid_url", error_message: e.message))
        redirect_to(fallback)
      end
    end

    def allowed_return_hosts(allowed_hosts)
      req = request if defined?(request)
      hosts = Array(allowed_hosts).presence || [
        req&.respond_to?(:host_with_port) ? req.host_with_port : nil,
        req&.respond_to?(:host) ? req.host : nil,
      ]

      hosts.filter_map { |host| normalized_host_with_optional_port(host) }.uniq
    end

    def normalized_host_with_optional_port(value)
      raw = value.to_s.strip.downcase
      return if raw.blank?

      uri = URI.parse(raw.match?(%r{\Ahttps?://}) ? raw : "//#{raw}")
      host = uri.host
      return if host.blank?

      if uri.port && uri.port != default_port_for(uri.scheme)
        "#{host}:#{uri.port}"
      else
        host
      end
    rescue URI::InvalidURIError
      nil
    end

    def host_with_optional_port(uri)
      host = uri.host.to_s.downcase
      return host if uri.port.blank? || uri.port == default_port_for(uri.scheme)

      "#{host}:#{uri.port}"
    end

    def default_port_for(scheme)
      (scheme == "https") ? 443 : 80
    end
  end
end

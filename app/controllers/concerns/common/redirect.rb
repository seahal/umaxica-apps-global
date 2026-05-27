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

    def redirect_to_pt(default:, pt: params[:pt], **)
      result = Redirects::PathTargetResolver.call(pt, source: :raw_pt)
      log_redirect_target_failure(result) unless result.ok? || pt.blank?

      redirect_to(result.ok? ? result.value : default, allow_other_host: false, **)
    end

    def redirect_to_nt(key, scope: nil, **)
      result = Redirects::NavigationTargetResolver.call(
        key,
        routes: self,
        params: redirect_target_context_params,
        scope: scope,
      )
      return redirect_to(result.value, allow_other_host: false, **) if result.ok?

      log_redirect_target_failure(result)
      render plain: I18n.t("errors.messages.invalid_request", default: "Invalid request"),
             status: :unprocessable_content
    end

    def redirect_to_xt(key, path: "/", query: {}, **)
      result = Redirects::ExternalTargetResolver.call(key, path: path, query: query)
      return redirect_to(result.value, allow_other_host: true, **) if result.ok?

      log_redirect_target_failure(result)
      render plain: I18n.t("errors.messages.invalid_request", default: "Invalid request"),
             status: :unprocessable_content
    end

    def redirect_to_xt_url(url, allowed_urls:, **)
      result = Redirects::ExternalTargetResolver.url(url, allowed_urls: allowed_urls)
      return redirect_to(result.value, allow_other_host: true, **) if result.ok?

      log_redirect_target_failure(result)
      render plain: I18n.t("errors.messages.invalid_request", default: "Invalid request"),
             status: :unprocessable_content
    end

    def redirect_to_jump_rt(token, **)
      result = Redirects::JumpGatewayUrl.call(token)
      return redirect_to(result.value, allow_other_host: true, **) if result.ok?

      log_redirect_target_failure(result)
      render plain: I18n.t("errors.messages.invalid_request", default: "Invalid request"),
             status: :unprocessable_content
    end

    def redirect_to_jump_url(url, namespace: jump_rt_issuer_namespace, dst: "internal", **)
      token = JumpRt::Issuer.call(namespace: namespace, url: url, dst: dst)
      return redirect_to_jump_rt(token, **) if token.present?

      result = Redirects::TargetResult.failure(
        kind: :xt, source: :jump_rt_issue, reason: :invalid_jump_rt_url,
        unsafe_value: url,
      )
      log_redirect_target_failure(result)
      render plain: I18n.t("errors.messages.invalid_request", default: "Invalid request"),
             status: :unprocessable_content
    end

    def resolve_redirect_target(priority:, default:)
      result = Redirects::PriorityResolver.call(
        priority: priority,
        routes: self,
        params: redirect_target_context_params,
        default: default,
      )
      log_redirect_target_failure(result) unless result.ok?
      result
    end

    def safe_redirect_to(target, fallback: "/", **)
      result = Redirects::PathTargetResolver.call(target, source: :legacy_safe_redirect)
      safe_path = result.value if result.ok?
      log_redirect_target_failure(result) unless result.ok? || target.blank?

      if safe_path
        redirect_to(safe_path, allow_other_host: false, **)
      else
        redirect_to(fallback, allow_other_host: false, **)
      end
    end

    def safe_redirect_back_or_to(fallback, **)
      result = Redirects::PathTargetResolver.call(request.referer, source: :referer)
      safe_path = result.value if result.ok?
      redirect_to(safe_path || fallback, allow_other_host: false, **)
    end

    def safe_internal_path(target)
      result = Redirects::PathTargetResolver.call(target, source: :internal_path)
      result.value if result.ok?
    end

    def safe_return_path(target, allowed_hosts: nil)
      return safe_internal_path(target) if target.to_s.start_with?("/")
      return nil if allowed_hosts.present?

      uri = URI.parse(target.to_s)
      return nil unless uri.is_a?(URI::HTTP) && uri.userinfo.blank?

      allowed = allowed_return_hosts(allowed_hosts)
      return nil unless allowed.include?(host_with_optional_port(uri))

      safe_internal_path(uri.request_uri)
    rescue URI::InvalidURIError
      nil
    end

    alias safe_return_to_path safe_return_path

    def generate_redirect_url(target)
      safe_path = safe_internal_path(target)
      Base64.urlsafe_encode64(safe_path, padding: false) if safe_path.present?
    end

    def jump_to_generated_url(target, fallback:)
      decoded = Base64.urlsafe_decode64(target.to_s)
      safe_redirect_to(decoded, fallback: fallback)
    rescue ArgumentError
      safe_redirect_to(nil, fallback: fallback)
    end

    private :safe_return_path, :generate_redirect_url, :jump_to_generated_url

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

    def redirect_target_context_params
      {
        ri: params[:ri],
        surface: redirect_target_surface,
      }
    end

    def redirect_target_surface
      return surface_from_controller_name if respond_to?(
        :surface_from_controller_name,
        true,
      ) && surface_from_controller_name.present?
      return Actor.tld if defined?(Actor) && Actor.respond_to?(:tld) && Actor.tld.present?

      "app"
    end

    def jump_rt_issuer_namespace
      JumpRt::Surface.namespace_for_controller(self.class.name)
    end

    def log_redirect_target_failure(result)
      return if result.ok?

      request_id = request.request_id if respond_to?(:request, true) && request.respond_to?(:request_id)
      Rails.logger.info(
        LogEvent.format(
          "redirect_target.rejected",
          kind: result.kind,
          source: result.source,
          reason: result.failure_reason,
          unsafe_value_digest: result.unsafe_value_digest,
          request_id: request_id,
        ),
      )
    end
  end
end

# typed: false
# frozen_string_literal: true
# TODO: please check is this file need us?


# Rate limiting concern backed by Rails 8.1's built-in `rate_limit` DSL.
#
# Uses a dedicated RedisCacheStore (Valkey) for atomic counter operations.
# Include this concern in any controller to get default rate limits:
#   - Web requests: 300 req/min by IP
#   - API requests: 600 req/min by IP
#
# Controllers can declare additional limits via the standard Rails DSL:
#   rate_limit to: 5, within: 1.minute, store: rate_limit_store, only: :create, name: "login"
module RateLimit
  extend ActiveSupport::Concern

  # Lazy-initialised per-process store.
  STORE_REGISTRY = {}
  private_constant :STORE_REGISTRY

  SKIP_DEFAULT_CLASSES = Concurrent::Set.new
  private_constant :SKIP_DEFAULT_CLASSES

  def self.store
    STORE_REGISTRY[Process.pid] ||= build_store
  end

  def self.build_store
    configured_store = Rails.configuration.x.rate_limit[:store]
    return configured_store.call if configured_store.respond_to?(:call)
    return configured_store if configured_store

    url = ENV.fetch("RATE_LIMIT_REDIS_URL", "redis://localhost:6379/0")
    ActiveSupport::Cache::RedisCacheStore.new(url: url, namespace: "rate_limit")
  end

  DEFAULT_RETRY_AFTER = 60
  DEFAULT_RATE_LIMIT = 300
  DEFAULT_RATE_WINDOW = 1.minute

  def self.default_rate_limit
    DEFAULT_RATE_LIMIT
  end

  def self.default_rate_window
    DEFAULT_RATE_WINDOW
  end

  # Default: 300 req/min by IP address.
  # Controllers can override or add custom limits using the standard Rails DSL.
  #
  # Example:
  #   class MyController < ApplicationController
  #     include RateLimit
  #     rate_limit to: 5, within: 1.minute, only: :create, name: "login"
  #   end
  #
  # To opt out of the default rate limit (when you have your own):
  #   class MyController < ApplicationController
  #     include RateLimit
  #     has_custom_rate_limit!
  #     rate_limit to: 10, within: 1.minute, name: "custom"
  #   end

  class_methods do
    def rate_limit_store
      RateLimit.store
    end

    def has_custom_rate_limit!
      SKIP_DEFAULT_CLASSES.add(self)
    end

    def skip_default_rate_limit?
      SKIP_DEFAULT_CLASSES.include?(self)
    end

    alias_method :has_custom_rate_limit?, :skip_default_rate_limit?
  end

  protected

  def skip_default_rate_limit?
    self.class.skip_default_rate_limit?
  end

  alias_method :has_custom_rate_limit?, :skip_default_rate_limit?

  private

  def check_default_rate_limit
    limit = RateLimit.default_rate_limit
    window = RateLimit.default_rate_window
    key = "rate_limit:default:#{request.remote_ip}"

    current = RateLimit.store.increment(key, 1, expires_in: window)
    return unless current && current > limit

    render_rate_limit_exceeded("default_ip", window.to_i)
  end

  def render_rate_limit_exceeded(rule_name, retry_after = DEFAULT_RETRY_AFTER)
    retry_after_seconds = Integer(retry_after.to_s, 10).positive? ? Integer(retry_after.to_s, 10) : DEFAULT_RETRY_AFTER
    message = I18n.t("errors.rate_limit.exceeded")

    response.headers["X-RateLimit-Layer"] = "rails"
    response.headers["X-RateLimit-Rule"] = rule_name.to_s
    response.headers["Retry-After"] = retry_after_seconds.to_s

    if request.format.json?
      render json: { error: "rate_limited", rule: rule_name.to_s, message: message },
             status: :too_many_requests
    else
      render plain: message, status: :too_many_requests
    end
  end

  def handle_rate_limit_exceeded!(rule_name, retry_after = DEFAULT_RETRY_AFTER)
    render_rate_limit_exceeded(rule_name, retry_after)
  end
end

# typed: false
# frozen_string_literal: true

module StepUp
  module Cooldowns
    WINDOWS = {
      email_otp: 60.seconds,
      passkey: 5.seconds,
      totp: 5.seconds,
    }.freeze

    module_function

    def key(actor, method)
      "step_up_cooldown:#{actor.class.name.underscore}:#{actor.id}:#{method}"
    end

    def active_methods(actor)
      cache_keys_by_method = WINDOWS.keys.index_with { |method| key(actor, method) }
      active_cache_keys = Rails.cache.read_multi(*cache_keys_by_method.values).keys

      cache_keys_by_method.filter_map do |method, cache_key|
        method.to_sym if active_cache_keys.include?(cache_key)
      end
    end
  end
end

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
      keys = WINDOWS.keys.select { |method| Rails.cache.exist?(key(actor, method)) }
      keys.map(&:to_sym)
    end
  end
end

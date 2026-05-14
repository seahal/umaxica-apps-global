# typed: false
# frozen_string_literal: true

module StepUp
  module CooldownStamp
    module_function

    def call(actor, method)
      method = method.to_sym
      expires_in = Cooldowns::WINDOWS.fetch(method)

      Rails.cache.write(Cooldowns.key(actor, method), true, expires_in: expires_in)
    end
  end
end

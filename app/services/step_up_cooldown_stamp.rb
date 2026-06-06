# typed: false
# frozen_string_literal: true

module StepUpCooldownStamp
  module_function

  def call(actor, method)
    method = method.to_sym
    expires_in = StepUpCooldowns::WINDOWS.fetch(method)

    Rails.cache.write(StepUpCooldowns.key(actor, method), true, expires_in: expires_in)
  end
end

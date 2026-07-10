# typed: false
# frozen_string_literal: true

module StepUpCooldownStamp
  module_function

  def call(_actor, method)
    method = method.to_sym
    StepUpCooldowns::WINDOWS.fetch(method)

    nil
  end
end

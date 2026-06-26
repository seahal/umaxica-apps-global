# typed: false
# frozen_string_literal: true

module StepUpAvailableMethods
  module_function

  def call(subject, ticket: nil)
    return [] unless subject
    return [] if ticket&.attempt_count.to_i >= 5

    StepUpConfiguredMethods.call(subject) - StepUpCooldowns.active_methods(subject)
  end
end

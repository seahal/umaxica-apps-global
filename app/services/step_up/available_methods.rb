# typed: false
# frozen_string_literal: true

module StepUp
  module AvailableMethods
    module_function

    def call(subject, ticket: nil)
      return [] unless subject
      return [] if ticket&.attempt_count.to_i >= 5

      ConfiguredMethods.call(subject) - Cooldowns.active_methods(subject)
    end
  end
end

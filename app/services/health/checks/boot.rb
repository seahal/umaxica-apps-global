# typed: false
# frozen_string_literal: true

module Health
  module Checks
    # Startup check: confirms Rails finished initialization. Intentionally
    # lightweight - it must not touch external dependencies.
    class Boot
      def call
        return Health::DependencyResult.new(kind: :boot, status: :ok) if Rails.application.initialized?

        Health::DependencyResult.new(kind: :boot, status: :starting, message: "Application is starting")
      end
    end
  end
end

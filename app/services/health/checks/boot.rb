# typed: false
# frozen_string_literal: true

module Health
  module Checks
    class Boot
      def call
        return Health::Check::Result.new(kind: :boot, status: :ok) if Rails.application.initialized?

        Health::Check::Result.new(kind: :boot, status: :starting, message: "Application is starting")
      end
    end
  end
end

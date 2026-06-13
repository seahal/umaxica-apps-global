# typed: false
# frozen_string_literal: true

module Health
  module Checks
    # Readiness dependency check: confirms the writing and reading database
    # roles answer a trivial query within a deadline. The underlying exception
    # is logged (internal) but never surfaced in the public response.
    class Database
      SQL = "SELECT 1"
      ROLES = %i(writing reading).freeze

      def initialize(record_class:, deadline: 0.2)
        @record_class = record_class
        @deadline = deadline
      end

      def call
        with_deadline do
          check_roles
        end

        Health::DependencyResult.new(kind: :database, status: :ok)
      rescue StandardError => e
        Rails.logger.info(
          JitLogEvent.format("health_check.database_failed", error_class: e.class.name),
        )
        Health::DependencyResult.new(kind: :database, status: :unready, message: "Dependency unavailable")
      end

      private

      attr_reader :record_class, :deadline

      def check_roles
        ROLES.each do |role|
          record_class.connected_to(role: role) do
            record_class.with_connection { |connection| connection.execute(SQL) }
          end
        end
      end

      def with_deadline(&)
        Timeout.timeout(deadline, Health::DeadlineExceeded, &)
      end
    end
  end
end

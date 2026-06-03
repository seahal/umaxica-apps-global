# typed: false
# frozen_string_literal: true

module Identity
  module TelephoneCeremony
    class ReplayStore
      MODEL_BY_SURFACE = {
        "app" => ClientTelephoneCeremonyTransaction,
        "com" => VisitorTelephoneCeremonyTransaction,
        "org" => OperatorTelephoneCeremonyTransaction,
      }.freeze

      def self.for(surface)
        new(transaction_class: MODEL_BY_SURFACE.fetch(surface.to_s) { raise Error, "surface is invalid" })
      end

      def initialize(transaction_class:)
        @transaction_class = transaction_class
      end

      def create_transaction!(**attributes)
        transaction_class.create_transaction!(**attributes)
      end

      def find_transaction!(transaction_id)
        transaction_class.find_by!(transaction_id: transaction_id)
      end

      def consumed?(result_jti)
        transaction_class.exists?(result_jti: result_jti)
      end

      private

      attr_reader :transaction_class
    end
  end
end

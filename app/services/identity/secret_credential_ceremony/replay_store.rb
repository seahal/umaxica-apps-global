# typed: false
# frozen_string_literal: true

module Identity
  module SecretCredentialCeremony
    class ReplayStore
      MODELS = {
        "app" => ClientSecretCredentialCeremonyTransaction,
        "com" => VisitorSecretCredentialCeremonyTransaction,
        "org" => OperatorSecretCredentialCeremonyTransaction,
      }.freeze

      def self.for(surface)
        new(MODELS.fetch(surface.to_s) { raise Error, "surface is invalid" })
      end

      def initialize(model_class)
        @model_class = model_class
      end

      def create_transaction!(**attributes)
        model_class.create_transaction!(**attributes)
      end

      def find_transaction!(transaction_id)
        model_class.find_by!(transaction_id: transaction_id)
      rescue ActiveRecord::RecordNotFound
        raise Error, "transaction is not found"
      end

      private

      attr_reader :model_class
    end
  end
end

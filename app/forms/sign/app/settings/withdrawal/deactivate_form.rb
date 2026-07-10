# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Settings
      module Withdrawal
        class DeactivateForm
          include ActiveModel::Model

          attr_accessor :ack_deactivate_today

          validates :ack_deactivate_today, acceptance: true
        end
      end
    end
  end
end

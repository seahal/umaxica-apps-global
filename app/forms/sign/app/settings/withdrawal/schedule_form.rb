# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Settings
      module Withdrawal
        class ScheduleForm
          include ActiveModel::Model

          attr_accessor :ack_schedule_purge

          validates :ack_schedule_purge, acceptance: true
        end
      end
    end
  end
end

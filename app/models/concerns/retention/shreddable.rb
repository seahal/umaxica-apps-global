# typed: false
# frozen_string_literal: true

module Retention
  module Shreddable
    extend ActiveSupport::Concern

    SENTINEL = ::Float::INFINITY

    included do
      const_set(:SHREDDING_SENTINEL, Retention::Shreddable::SENTINEL) unless const_defined?(:SHREDDING_SENTINEL, false)

      attribute :purged_at, :datetime, default: -> { SHREDDING_SENTINEL }
      define_model_callbacks :shred, only: %i(before after)

      validates :purged_at, presence: true

      scope :shreddable, -> { where(arel_table[:purged_at].lteq(Time.current)) }
    end

    def shreddable?
      !future_time?(purged_at)
    end

    def schedule_shredding_at(time)
      update(purged_at: time)
    end

    def schedule_shredding_at!(time)
      update!(purged_at: time)
    end

    def unschedule_shredding
      update(purged_at: self.class::SHREDDING_SENTINEL)
    end

    def unschedule_shredding!
      update!(purged_at: self.class::SHREDDING_SENTINEL)
    end

    def shred
      return false unless shreddable?

      run_callbacks(:shred) do
        destroy
      end
    end

    def shred!
      raise ActiveRecord::RecordNotDestroyed.new("Record is not scheduled for shredding", self) unless shreddable?

      run_callbacks(:shred) do
        destroy!
      end
    end

    private

    def future_time?(value)
      return true if value.respond_to?(:infinite?) && value.infinite?

      value.present? && value > Time.current
    end

    class_methods do
      def shred_all
        shreddable.each(&:shred)
      end

      def shred_all!
        shreddable.each(&:shred!)
      end
    end
  end
end

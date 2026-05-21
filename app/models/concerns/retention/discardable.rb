# typed: false
# frozen_string_literal: true

module Retention
  module Discardable
    extend ActiveSupport::Concern

    SENTINEL = ::Float::INFINITY

    included do
      const_set(:SENTINEL, Retention::Discardable::SENTINEL) unless const_defined?(:SENTINEL, false)

      attribute :discarded_at, :datetime, default: -> { SENTINEL }
      define_model_callbacks :discard, :undiscard, only: %i(before after)

      validates :discarded_at, presence: true

      scope :kept, -> { where(arel_table[:discarded_at].gt(Time.current)) }
      scope :discarded, -> { where(discarded_at: ..Time.current) }
      scope :with_discarded, -> { all }
    end

    def kept?
      future_time?(discarded_at)
    end

    def discarded?
      !kept?
    end

    def undiscarded?
      kept?
    end

    def discard
      return true if discarded?

      run_callbacks(:discard) do
        update(discarded_at: Time.current)
      end
    end

    def discard!
      return true if discarded?

      run_callbacks(:discard) do
        update!(discarded_at: Time.current)
        true
      end || raise_record_not_saved!("Failed to discard the record")
    end

    def undiscard
      return true if kept?

      run_callbacks(:undiscard) do
        update(discarded_at: SENTINEL)
      end
    end

    def undiscard!
      return true if kept?

      run_callbacks(:undiscard) do
        update!(discarded_at: SENTINEL)
        true
      end || raise_record_not_saved!("Failed to undiscard the record")
    end

    private

    def future_time?(value)
      return true if value.respond_to?(:infinite?) && value.infinite?

      value.present? && value > Time.current
    end

    def raise_record_not_saved!(message)
      raise ActiveRecord::RecordNotSaved.new(message, self)
    end

    class_methods do
      def discard_all
        kept.each(&:discard)
      end

      def discard_all!
        kept.each(&:discard!)
      end

      def undiscard_all
        discarded.each(&:undiscard)
      end

      def undiscard_all!
        discarded.each(&:undiscard!)
      end
    end
  end
end

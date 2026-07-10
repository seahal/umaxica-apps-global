# typed: false
# frozen_string_literal: true

module Cms
  module PublicationPredicates
    def scheduled_at?(time) = !cancelled? && time < effective_from

    def effective_at?(time) = !cancelled? && time >= effective_from && (effective_until.nil? || time < effective_until)

    def ended_at?(time) = cancelled? || (effective_until.present? && time >= effective_until)

    def cancelled? = cancelled_at.present?

    def terminated? = terminated_at.present?

    def naturally_expired_at?(time) = !cancelled? && !terminated? && effective_until.present? && time >= effective_until
  end
end

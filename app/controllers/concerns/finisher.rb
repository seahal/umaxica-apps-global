# typed: false
# frozen_string_literal: true

module Finisher
  extend ActiveSupport::Concern

  def purge_current
    Actor.clear
  end

  private

  def finish_request
    # no-op
  rescue StandardError => e
    Rails.logger.warn("[Finisher] #{e.class}: #{e.message}")
  end
end

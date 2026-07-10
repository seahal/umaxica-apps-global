# typed: false
# frozen_string_literal: true

module VerificationOperator
  extend ActiveSupport::Concern

  include VerificationBase

  private

  def actor_operator?
    true
  end
end

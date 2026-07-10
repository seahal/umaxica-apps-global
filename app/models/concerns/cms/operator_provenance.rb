# typed: false
# frozen_string_literal: true

module Cms
  module OperatorProvenance
    extend ActiveSupport::Concern

    included do
      validates :created_by_operator_public_id, presence: true, if: -> { respond_to?(:created_by_operator_public_id) }
    end
  end
end

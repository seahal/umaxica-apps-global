# typed: false
# frozen_string_literal: true

module CmsOperatorProvenance
  extend ActiveSupport::Concern

  included do
    validates :created_by_operator_public_id, presence: true, if: -> { respond_to?(:created_by_operator_public_id) }
  end
end

module Cms
  OperatorProvenance = ::CmsOperatorProvenance
end

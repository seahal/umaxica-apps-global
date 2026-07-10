# typed: false
# frozen_string_literal: true

module CmsOwnershipRules
  module_function

  def at_most_one?(*owners) = owners.count(&:present?) <= 1

  def exactly_one?(*owners) = owners.count(&:present?) == 1
end

module Cms
  OwnershipRules = ::CmsOwnershipRules
end

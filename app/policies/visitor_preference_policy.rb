# typed: false
# frozen_string_literal: true

class VisitorPreferencePolicy < ApplicationPolicy
  def update?
    user.is_a?(Visitor) && record.is_a?(VisitorPreference) && record.visitor_id == user.id
  end
end

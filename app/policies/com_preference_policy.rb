# typed: false
# frozen_string_literal: true

class ComPreferencePolicy < ApplicationPolicy
  def update?
    record == ComPreference || record.is_a?(ComPreference)
  end
end

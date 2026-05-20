# typed: false
# frozen_string_literal: true

class AppPreferencePolicy < ApplicationPolicy
  def update?
    record == AppPreference || record.is_a?(AppPreference)
  end
end

# typed: false
# frozen_string_literal: true

class OrgPreferencePolicy < ApplicationPolicy
  def update?
    record == OrgPreference || record.is_a?(OrgPreference)
  end
end

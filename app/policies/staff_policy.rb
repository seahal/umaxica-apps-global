# typed: false
# frozen_string_literal: true

class StaffPolicy < ApplicationPolicy
  def revoke_all?
    actor.is_a?(Staff) && actor.id == record.id
  end

  def purge_sessions?
    actor.is_a?(Staff)
  end
end

# typed: false
# frozen_string_literal: true

class CustomerPolicy < ApplicationPolicy
  def revoke_all?
    actor.is_a?(Customer) && actor.id == record.id
  end

  def purge_sessions?
    actor.is_a?(Staff)
  end
end

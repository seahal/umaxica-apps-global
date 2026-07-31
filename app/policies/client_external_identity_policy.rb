# typed: false
# frozen_string_literal: true

class ClientExternalIdentityPolicy < ApplicationPolicy
  def destroy?
    owner?
  end
end

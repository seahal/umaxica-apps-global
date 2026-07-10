# typed: false
# frozen_string_literal: true

class ClientAppleIdentityPolicy < ApplicationPolicy
  def destroy?
    owner?
  end
end

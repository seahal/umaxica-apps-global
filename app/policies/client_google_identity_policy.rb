# typed: false
# frozen_string_literal: true

class ClientGoogleIdentityPolicy < ApplicationPolicy
  def destroy?
    owner?
  end
end

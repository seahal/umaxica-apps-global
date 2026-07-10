# typed: false
# frozen_string_literal: true

module Authentication
  class AccessPolicy < ApplicationPolicy
    def public_strict?
      true
    end

    def auth_required?
      record.logged_in
    end

    def guest_only?
      !record.logged_in || record.current_resource_deactivated
    end
  end
end

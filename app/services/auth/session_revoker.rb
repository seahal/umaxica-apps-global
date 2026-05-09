# typed: false
# frozen_string_literal: true

module Auth
  class SessionRevoker
    def self.revoke_all_for(resource)
      tokens = tokens_for(resource)
      tokens.find_each(&:revoke!)
    end

    def self.tokens_for(resource)
      case resource
      when User
        UserToken.where(user_id: resource.id)
      when Staff
        StaffToken.where(staff_id: resource.id)
      when Customer
        CustomerToken.where(customer_id: resource.id)
      else
        raise ArgumentError, "Unsupported resource type: #{resource.class}"
      end
    end
  end
end

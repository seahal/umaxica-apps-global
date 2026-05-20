# typed: false
# frozen_string_literal: true

module Authentication
  class SessionRevoker
    def self.revoke_all_for(resource)
      tokens = tokens_for(resource)
      tokens.find_each(&:revoke!)
    end

    def self.tokens_for(resource)
      case resource
      when ::Client
        ::ClientToken.where(user_id: resource.id)
      when ::Operator
        ::OperatorToken.where(staff_id: resource.id)
      when ::Visitor
        ::VisitorToken.where(visitor_id: resource.id)
      else
        raise ArgumentError, "Unsupported resource type: #{resource.class}"
      end
    end
  end
end

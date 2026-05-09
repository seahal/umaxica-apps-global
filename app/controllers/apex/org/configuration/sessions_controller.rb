# typed: false
# frozen_string_literal: true

module Apex
  module Org
    module Configuration
      class SessionsController < ApplicationController
        def purge
          target_type = params[:target_type]
          target_id = params[:target_id]

          case target_type
          when "user"
            UserToken.where(user_id: target_id).find_each(&:revoke!)
          when "staff"
            StaffToken.where(staff_id: target_id).find_each(&:revoke!)
          when "customer"
            CustomerToken.where(customer_id: target_id).find_each(&:revoke!)
          else
            return head :bad_request
          end

          Rails.event.notify(
            "security.session_purge",
            actor_type: "Staff",
            actor_id: current_resource&.id,
            target_type: target_type.capitalize,
            target_id: target_id,
          )

          redirect_to(apex_org_configuration_path, status: :see_other)
        end
      end
    end
  end
end

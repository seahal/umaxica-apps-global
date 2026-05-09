# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Configuration
      class EmailsController < ApplicationController
        auth_required!

        include ::Verification::Staff

        VERIFIED_EMAIL_STATUSES = [
          StaffEmailStatus::ACTIVE,
          StaffEmailStatus::VERIFIED,
        ].freeze

        before_action :authenticate_staff!

        def index
          @staff_emails = current_staff.staff_emails.order(created_at: :asc)
        end

        def edit
          @staff_email = current_staff.staff_emails.find_by!(public_id: params.expect(:id))
        end

        def destroy
          @staff_email = current_staff.staff_emails.find_by!(public_id: params.expect(:id))

          if @staff_email.undeletable?
            redirect_to(
              sign_org_configuration_emails_path,
              alert: t("sign.org.configuration.email.destroy.protected"),
            )
            return
          end

          unless removable_email?(@staff_email)
            redirect_to(
              sign_org_configuration_emails_path,
              alert: t("sign.org.configuration.email.destroy.last_method"),
            )
            return
          end

          @staff_email.destroy!
          redirect_to(
            sign_org_configuration_emails_path,
            notice: t("sign.org.configuration.email.destroy.success"),
            status: :see_other,
          )
        end

        private

        def removable_email?(staff_email)
          current_staff.staff_emails
            .where(staff_identity_email_status_id: VERIFIED_EMAIL_STATUSES)
            .where.not(id: staff_email.id)
            .exists?
        end

        def verification_required_action?
          true
        end

        def verification_scope
          "configuration_email"
        end
      end
    end
  end
end

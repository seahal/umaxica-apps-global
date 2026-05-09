# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Configuration
      class TelephonesController < ApplicationController
        auth_required!

        include Sign::StaffTelephoneRegistrable
        include ::Verification::Staff

        before_action :authenticate_staff!

        def index
          @staff_telephones = current_staff.staff_telephones.order(created_at: :asc)
        end

        def new
          @staff_telephone = StaffTelephone.new
        end

        def edit
          @staff_telephone = current_staff.staff_telephones.find(params.expect(:id))
        end

        def create
          tel_params = params.expect(staff_telephone: [:raw_number, :number])
          number = tel_params[:raw_number] || tel_params[:number]

          unless initiate_staff_telephone_verification(current_staff, number)
            render :new, status: :unprocessable_content
            return
          end

          redirect_to(edit_sign_org_configuration_telephone_path(@staff_telephone.id))
        end

        def destroy
          @staff_telephone = current_staff.staff_telephones.find(params.expect(:id))

          unless removable_telephone?(@staff_telephone)
            redirect_to(
              sign_org_configuration_telephones_path,
              alert: t("sign.org.configuration.telephone.destroy.last_method"),
            )
            return
          end

          @staff_telephone.destroy!
          redirect_to(
            sign_org_configuration_telephones_path,
            notice: t("sign.org.configuration.telephone.destroy.success"),
            status: :see_other,
          )
        end

        private

        def removable_telephone?(staff_telephone)
          verified_staff_telephones_for(current_staff).where.not(id: staff_telephone.id).exists? ||
            current_staff.staff_emails.exists?(staff_identity_email_status_id: [StaffEmailStatus::ACTIVE, StaffEmailStatus::VERIFIED])
        end

        def verification_required_action?
          true
        end

        def verification_scope
          "configuration_telephone"
        end
      end
    end
  end
end

# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Configuration
      class TelephonesController < PrivateController
        include Sign::OperatorTelephoneRegistrable
        include ::Verification::Operator

        before_action :authenticate_operator!

        def index
          @staff_telephones = current_operator.staff_telephones.order(created_at: :asc)
        end

        def new
          @staff_telephone = OperatorTelephone.new
        end

        def edit
          @staff_telephone = current_operator.staff_telephones.find(params(:id))
        end

        def create
          tel_params = params(staff_telephone: [:raw_number, :number])
          number = tel_params[:raw_number] || tel_params[:number]

          unless initiate_staff_telephone_verification(current_operator, number)
            render :new, status: :unprocessable_content
            return
          end

          redirect_to(edit_sign_org_configuration_telephone_path(@staff_telephone.id))
        end

        def destroy
          @staff_telephone = current_operator.staff_telephones.find(params(:id))

          unless AuthMethodGuard.can_remove_telephone?(current_operator, @staff_telephone)
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

# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Identity
      class TelephonesController < ::Base::Org::ApplicationController
        include SignOperatorTelephoneRegistrable
        include ::SignSettingsAuthorityRedirect

        include ::VerificationOperator

        AUTHENTICATION_MODE = :private

        before_action :authenticate_operator!
        # Object-level authorization (ActionPolicy): new/create gate the actor type; edit
        # authorize the owned record (find is owner-scoped, so a non-owner gets 404 first).
        # Verification guards remain in place.
        before_action :authorize_telephone_registration!, only: %i(new create)

        def index
          @staff_telephones = current_operator.staff_telephones.order(created_at: :asc)
        end

        def new
          @staff_telephone = OperatorTelephone.new
        end

        def edit
          @staff_telephone = current_operator.staff_telephones.find(params(:id))
          authorize!(@staff_telephone)
        end

        def create
          tel_params = params(staff_telephone: [:raw_number, :number])
          number = tel_params[:raw_number] || tel_params[:number]

          unless initiate_staff_telephone_verification(current_operator, number)
            render :new, status: :unprocessable_content
            return
          end

          redirect_to(edit_base_org_identity_telephones_registration_path(ri: params[:ri]))
        end

        def destroy
          telephone = current_operator.staff_telephones.find(params(:id))
          authorize!(telephone)

          unless AuthMethodGuard.can_remove_telephone?(current_operator, telephone)
            redirect_to(
              base_org_identity_telephones_path(ri: params[:ri]),
              alert: t("sign.org.settings.telephone.destroy.last_method"),
            )
            return
          end

          telephone.destroy!
          redirect_to(
            base_org_identity_telephones_path(ri: params[:ri]),
            notice: t("sign.org.settings.telephone.destroy.success"),
            status: :see_other,
          )
        end

        private

        def authorize_telephone_registration!
          authorize!(OperatorTelephone, to: :create?)
        end

        def verification_required_action?
          true
        end

        def verification_scope
          "settings_telephone"
        end
      end
    end
  end
end

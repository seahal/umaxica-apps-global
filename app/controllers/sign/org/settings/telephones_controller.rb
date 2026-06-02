# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Settings
      class TelephonesController < Sign::Org::ApplicationController
        include Sign::OperatorTelephoneRegistrable

        include ::Verification::Operator

        AUTHENTICATION_MODE = :private

        before_action :authenticate_operator!
        # Object-level authorization (ActionPolicy): index/new/create gate the actor type; edit/destroy
        # authorize the owned record (find is owner-scoped, so a non-owner gets 404 first).
        # Verification guards remain in place.
        before_action :authorize_telephones!, only: %i(index)
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

          redirect_to(edit_sign_org_settings_telephone_path(@staff_telephone.id))
        end

        def destroy
          @staff_telephone = current_operator.staff_telephones.find(params(:id))
          authorize!(@staff_telephone)

          unless AuthMethodGuard.can_remove_telephone?(current_operator, @staff_telephone)
            redirect_to(
              sign_org_settings_telephones_path,
              alert: t("sign.org.settings.telephone.destroy.last_method"),
            )
            return
          end

          @staff_telephone.destroy!
          redirect_to(
            sign_org_settings_telephones_path,
            notice: t("sign.org.settings.telephone.destroy.success"),
            status: :see_other,
          )
        end

        private

        def authorize_telephones!
          authorize!(OperatorTelephone, to: :index?)
        end

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

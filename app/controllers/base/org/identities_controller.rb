# typed: false
# frozen_string_literal: true

module Base
  module Org
    class IdentitiesController < Base::Org::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_operator!

      def show
        authorize!(current_operator, to: :show?)
        render inertia: true, props: {
          title: "Identity",
          description: "Signed in",
          sections: [
            {
              heading: "Account",
              items: [
                {
                  label: t("sign.app.settings.show.logout"),
                  href: new_base_org_sign_out_path(ri: params[:ri]),
                },
              ],
            },
          ],
        }
      end
    end
  end
end

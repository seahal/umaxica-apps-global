# typed: false
# frozen_string_literal: true

module Base
  module Com
    class IdentitiesController < Base::Com::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_visitor!

      def show
        authorize!(current_visitor, to: :show?)
        render inertia: true, props: {
          title: "Identity",
          description: "Signed in",
          sections: [
            {
              heading: "Account",
              items: [
                {
                  label: t("sign.app.settings.show.logout"),
                  href: new_base_com_sign_out_path(ri: params[:ri]),
                },
              ],
            },
          ],
        }
      end
    end
  end
end

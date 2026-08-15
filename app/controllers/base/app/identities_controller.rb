# typed: false
# frozen_string_literal: true

module Base
  module App
    class IdentitiesController < Base::App::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_client!

      def show
        authorize!(current_client, to: :show?)
        render inertia: true, props: {
          title: "Identity",
          description: "Signed in",
          credential_warning: apple_only_credential_warning_props,
          sections: [
            {
              heading: "Account",
              items: [
                {
                  label: t("sign.app.settings.show.logout"),
                  href: new_base_app_sign_out_path,
                },
              ],
            },
          ],
        }
      end
    end
  end
end

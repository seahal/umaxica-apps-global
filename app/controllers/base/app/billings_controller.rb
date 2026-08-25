# typed: false
# frozen_string_literal: true

module Base
  module App
    class BillingsController < Base::App::FullAccessController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def index
        authorize!(current_client, to: :show?)
        render inertia: true, props: {
          title: "Billings",
          description: t("billings.signed_in_required"),
        }
      end
    end
  end
end

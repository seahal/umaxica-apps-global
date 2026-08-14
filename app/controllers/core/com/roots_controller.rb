# typed: false
# frozen_string_literal: true

module Core
  module Com
    class RootsController < Core::Com::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :open

      def index
        render inertia: true, props: root_landing_props
      end

      private

      def root_landing_props
        {
          title: nil,
          heading: "Core Com",
          description: t("landing.thin_endpoint"),
          sign_up: nil,
          links: nil,
        }
      end
    end
  end
end

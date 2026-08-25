# typed: false
# frozen_string_literal: true

module Core
  module Dev
    class RootsController < Core::Dev::BareController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :deny_all

      def index
        render inertia: true, props: { title: nil }
      end
    end
  end
end

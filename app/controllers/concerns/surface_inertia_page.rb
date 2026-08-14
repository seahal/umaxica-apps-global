# typed: false
# frozen_string_literal: true

# Marks a controller as rendering Inertia pages, and derives its layout from its own surface.
#
# Including this concern is the single marker for "this controller renders Inertia": the layout is
# no longer a hand-written string that can name another surface's shell, and
# `grep -rl SurfaceInertiaPage app/controllers` is an accurate inventory. It pairs with
# `render inertia: true`, which derives the component name from the same controller_path.
#
# It also brings in the surface chrome, because a page rendered into the slim Inertia shell has no
# header or footer of its own: those are React components fed by the shared `chrome` prop.
module SurfaceInertiaPage
  extend ActiveSupport::Concern

  include SurfaceChrome

  included do
    family, surface = controller_path.to_s.split("/").first(2)

    if family.blank? || surface.blank?
      raise ArgumentError,
            "#{name} cannot derive an Inertia layout from controller_path #{controller_path.inspect}; " \
            "SurfaceInertiaPage expects a <family>/<surface>/... controller path"
    end

    layout "#{family}/#{surface}/inertia"
  end
end

# typed: false
# frozen_string_literal: true

# Define the Sign route-mapper macros (sign_routes/sign_surface/...) before the
# surface tables consume them. Required here rather than from an initializer so
# the macros exist regardless of initializer load order. See the file header.
require_relative "sign_route_mapper"
ActionDispatch::Routing::Mapper.include(SignRouteMapper)

Rails.application.routes.draw do
  # Acme owns the OP/Authorization Server and durable identity/session authority.
  draw :acme

  # Sign owns the credential gateway for sign-in/sign-up ceremonies.
  draw :sign

  # Core owns the regional BFF surface.
  draw :core

  # Base owns the Rails foundation/control-plane surface.
  draw :base

  # Palm owns the native bearer-token API surface.
  draw :palm

  # Help owns the public help content surface.
  draw :help

  # Info owns public informational content.
  draw :info

  # Docs owns the public documentation content surface.
  draw :docs

  # News owns the public news content surface.
  draw :news
end

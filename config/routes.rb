# typed: false
# frozen_string_literal: true

# Define the Auth route-mapper macros (auth_routes/auth_surface/...) before the
# surface tables consume them. Required here rather than from an initializer so
# the macros exist regardless of initializer load order. See the file header.
require_relative "auth_route_mapper"
ActionDispatch::Routing::Mapper.include(AuthRouteMapper)

Rails.application.routes.draw do
  # Base owns the OP/Authorization Server and durable identity/session authority.
  draw :base

  # Auth owns the credential gateway for sign-in/sign-up ceremonies.
  draw :auth

  # Core owns the regional BFF surface.
  draw :core

  # Side owns the Rails foundation/control-plane surface.
  draw :side

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

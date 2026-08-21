# typed: false
# frozen_string_literal: true

Rails.application.routes.draw do
  # Base owns the OP/Authorization Server and durable identity/session authority.
  draw :base

  # Auth owns the credential gateway for sign-in/sign-up ceremonies.
  draw :auth

  # Info owns public informational content.
  draw :info

  # Core owns the regional BFF surface.
  draw :core

  # Side owns the Rails foundation/control-plane surface.
  draw :side

  # Palm owns the native RP and bearer-token API surface.
  draw :palm

  # Help owns the public help content surface.
  draw :help

  # Docs owns the public documentation content surface.
  draw :docs

  # News owns the public news content surface.
  draw :news

  # Last, so that every surface above claims its own root first. Rails appends
  # `get "/" => "rails/welcome#index"` to this route set in development; claiming `/` here
  # leaves that append unreachable, so a hostname with no surface behind it answers 404
  # instead of the framework's welcome page.
  get "/", to: "unknown_hosts#show"
end

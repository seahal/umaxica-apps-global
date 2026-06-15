# typed: false
# frozen_string_literal: true

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

  # Docs owns the public documentation content surface.
  draw :docs

  # News owns the public news content surface.
  draw :news
end

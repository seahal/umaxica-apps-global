# typed: false
# frozen_string_literal: true

# Answers `/` for a `Host` that Host Authorization admits but no `constraints(host:)` block
# claims.
#
# Rails appends `get "/" => "rails/welcome#index"` to the route set in development. A hostname
# listed in `config.hosts` with no surface behind it therefore answered 200 with the framework's
# welcome page while every other path on it returned 404, so the surface read as alive to anything
# checking status codes. That is how a Core hostname served nothing for as long as it did.
#
# Inherits ApplicationController rather than a surface base class: by definition no surface owns
# this request, so there is no session, policy, or availability slot to consult. Nothing may be
# added here that reads a surface.
class UnknownHostsController < ApplicationController
  AUTHENTICATION_MODE = :bare

  # Machine-readable only, and deliberately not localized: the reader is an operator or a probe
  # diagnosing a misdirected request, never an end user. `unknown_host` reads alongside the
  # `unknown_fqdn` the availability gate returns, which is the neighbouring failure -- a Host that
  # does route but has no availability slot.
  def show
    render json: { error: "unknown_host" }, status: :not_found
  end
end

# typed: false
# frozen_string_literal: true

Rails.application.routes.draw do
  # Global application entrypoints
  # BFF
  draw :acme
  # sign in / up
  draw :sign
  # Regional application entrypoints
  # main page
  draw :core
  # Rails foundation/control-plane entrypoints
  draw :base
  # Native bearer-token API entrypoints
  draw :palm
  # Public read-only content entrypoints
  draw :help
  draw :docs
  draw :news
end

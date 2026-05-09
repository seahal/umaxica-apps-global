# typed: false
# frozen_string_literal: true

Rails.application.routes.draw do
  # BFF
  draw :apex
  # sign in / up
  draw :sign
  # Jump Page
  draw :jump

  # FIXME: remove these lines.
  root "inertia_example#index" # FIXME: remove
  get "inertia-example", to: "inertia_example#index" # FIXME: remove
end

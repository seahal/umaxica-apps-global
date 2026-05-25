# typed: false
# frozen_string_literal: true

routing_draw_path = Rails.root.join("config/routing")
Rails.application.routes.draw_paths << routing_draw_path unless Rails.application.routes.draw_paths.include?(routing_draw_path)

Rails.application.routes.draw do
  # Global application entrypoints
  draw :core
  draw :line
  draw :post

  # BFF
  draw :apex
  # sign in / up
  draw :sign
  # Jump Page
  draw :jump

  # FIXME: remove these lines.
  get "inertia-example", to: "inertia_example#index" # FIXME: remove
end

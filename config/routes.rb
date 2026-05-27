# typed: false
# frozen_string_literal: true

# FIXME: i think following lines are important for us?
routing_draw_path = Rails.root.join("config/routing")
unless Rails.application.routes.draw_paths.include?(routing_draw_path)
  Rails.application.routes.draw_paths << routing_draw_path
end

Rails.application.routes.draw do
  constraints host: /\A(?:.*\.)?(?:example\.com|example\.org)\z/ do
    root to: "inertia_example#index"
  end

  # Global application entrypoints
  # BFF
  draw :acme
  # sign in / up
  draw :sign
  # Regional application entrypoints
  draw :core
  draw :line
  draw :post
end

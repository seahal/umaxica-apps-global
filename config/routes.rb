# typed: false
# frozen_string_literal: true

# FIXME: i think following lines are important for us?
routing_draw_path = Rails.root.join("config/routing")
unless Rails.application.routes.draw_paths.include?(routing_draw_path)
  Rails.application.routes.draw_paths << routing_draw_path
end

Rails.application.routes.draw do
  # Global application entrypoints
  # BFF
  draw :apex
  # sign in / up
  draw :sign
  # Jump Page
  draw :jump

  # Regional application entrypoints
  draw :core
  draw :line
  draw :post
end

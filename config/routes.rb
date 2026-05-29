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
  # direct message
  draw :line
  # entrypoint for post
  draw :post
end

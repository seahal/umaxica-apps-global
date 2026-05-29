# typed: false
# frozen_string_literal: true
#
Rails.application.routes.draw do
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

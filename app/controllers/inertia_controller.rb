# typed: false
# frozen_string_literal: true

class InertiaController < ApplicationController
  # Share data with all Inertia responses
  # see https://inertia-rails.dev/guide/shared-data
  #   inertia_share client: -> { Actor.client&.as_json(only: [:id, :name, :email]) }
end

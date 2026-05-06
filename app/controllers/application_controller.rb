# typed: false
# frozen_string_literal: true

class ApplicationController < ActionController::Base
  protect_from_forgery using: :header_or_legacy_token
end

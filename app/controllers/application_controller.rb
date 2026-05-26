# typed: false
# frozen_string_literal: true

class ApplicationController < ActionController::Base
  AUTHENTICATION_MODE = :deny_all

  protect_from_forgery using: :header_or_legacy_token
end

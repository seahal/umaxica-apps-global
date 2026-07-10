# typed: false
# frozen_string_literal: true

module Palm
  module App
    class ApplicationController < ActionController::Base
      AUTHENTICATION_MODE = :bare

      layout "palm/app/application"
    end
  end
end

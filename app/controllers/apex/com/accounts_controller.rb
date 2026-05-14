# typed: false
# frozen_string_literal: true

module Apex
  module Com
    class AccountsController < ApplicationController
      auth_required!

      def index
      end
    end
  end
end

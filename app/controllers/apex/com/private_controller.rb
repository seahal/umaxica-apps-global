# typed: false
# frozen_string_literal: true

module Apex
  module Com
    class PrivateController < ApplicationController
      auth_required!
    end
  end
end

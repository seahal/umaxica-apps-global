# typed: false
# frozen_string_literal: true

class Jump::App::ToController < ApplicationController
  include Jump::ToRedirector

  JUMP_LINK_MODEL = AppJumpLink
end

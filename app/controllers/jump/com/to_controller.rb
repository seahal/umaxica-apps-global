# typed: false
# frozen_string_literal: true

class Jump::Com::ToController < ApplicationController
  include Jump::ToRedirector

  JUMP_LINK_MODEL = ComJumpLink
end

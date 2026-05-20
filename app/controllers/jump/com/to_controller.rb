# typed: false
# frozen_string_literal: true

class Jump::Com::ToController < Jump::Com::ApplicationController
  include Jump::ToRedirector

  JUMP_LINK_MODEL = ComJumpLink
end

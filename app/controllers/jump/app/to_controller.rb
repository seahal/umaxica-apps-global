# typed: false
# frozen_string_literal: true

class Jump::App::ToController < Jump::App::ApplicationController
  include Jump::ToRedirector

  JUMP_LINK_MODEL = AppJumpLink
end

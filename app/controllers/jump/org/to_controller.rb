# typed: false
# frozen_string_literal: true

class Jump::Org::ToController < ApplicationController
  include Jump::ToRedirector

  JUMP_LINK_MODEL = OrgJumpLink
end

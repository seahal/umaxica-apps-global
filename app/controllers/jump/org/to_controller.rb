# typed: false
# frozen_string_literal: true

class Jump::Org::ToController < Jump::Org::ApplicationController
  include Jump::ToRedirector

  JUMP_LINK_MODEL = OrgJumpLink
end

# typed: false
# frozen_string_literal: true

module AvatarSocialGraph
  class Error < StandardError; end

  class SelfEdgeError < Error; end

  class BlockedError < Error; end
end

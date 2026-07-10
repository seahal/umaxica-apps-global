# typed: false
# frozen_string_literal: true

module PromotionalEmailUnsubscribable
  extend ActiveSupport::Concern

  def promotional_unsubscribe_token
    PromotionalEmailUnsubscribeToken.generate(self, scope: promotional_unsubscribe_scope)
  end

  def valid_promotional_unsubscribe_token?(token)
    PromotionalEmailUnsubscribeToken.valid?(self, token, scope: promotional_unsubscribe_scope)
  end

  def unsubscribe_promotional!
    update!(promotional: false)
  end
end

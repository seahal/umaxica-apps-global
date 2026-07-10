# typed: false
# frozen_string_literal: true

module PublicId
  extend ActiveSupport::Concern

  included do
    before_create :generate_public_id
    before_validation :generate_public_id, on: :create

    validates :public_id, presence: true, length: { maximum: 21 }, uniqueness: true
  end

  def to_param
    public_id
  end

  private

  def generate_public_id
    self.public_id = Nanoid.generate(size: 21) if public_id.blank?
  end
end

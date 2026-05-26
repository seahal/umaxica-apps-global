# typed: false
# frozen_string_literal: true

module CoreRpBridge
  extend ActiveSupport::Concern

  included do
    include ::PublicId

    class_attribute :core_actor_association_name, instance_accessor: false
    class_attribute :core_actor_foreign_key, instance_accessor: false
    class_attribute :core_default_client_id, instance_accessor: false
    class_attribute :core_default_audience, instance_accessor: false
    class_attribute :core_default_host, instance_accessor: false

    before_validation :assign_core_rp_defaults

    validates :rp_client_id, presence: true, length: { maximum: 64 }
    validates :audience, presence: true, length: { maximum: 128 }
    validates :host, presence: true, length: { maximum: 255 }
  end

  class_methods do
    def core_rp_bridge(actor_association_name:, actor_foreign_key:, client_id:, audience:, host:)
      self.core_actor_association_name = actor_association_name
      self.core_actor_foreign_key = actor_foreign_key
      self.core_default_client_id = client_id
      self.core_default_audience = audience
      self.core_default_host = host

      validates actor_foreign_key, uniqueness: { scope: :rp_client_id }
    end
  end

  def actor
    public_send(self.class.core_actor_association_name)
  end

  def subject
    actor&.public_id
  end

  def core?
    rp_client_id == self.class.core_default_client_id && audience == self.class.core_default_audience
  end

  private

  def assign_core_rp_defaults
    self.rp_client_id = self.class.core_default_client_id if rp_client_id.blank?
    self.audience = self.class.core_default_audience if audience.blank?
    self.host = self.class.core_default_host if host.blank?
  end
end

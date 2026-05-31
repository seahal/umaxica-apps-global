# frozen_string_literal: true

module ChainSealable
  extend ActiveSupport::Concern

  class_methods do
    def chain_seal_payload_method(method_name)
      define_singleton_method(:chain_seal_payload_method_name) { method_name.to_sym }
    end

    def chain_seal_column(column_name)
      define_singleton_method(:chain_seal_column_name) { column_name.to_sym }
    end

    def chain_seal_key_provider(provider = nil, &block)
      material_provider = block || provider
      define_singleton_method(:chain_seal_key_provider_object) { material_provider }
    end

    def chain_seal_payload_method_name
      :chain_seal_payload
    end

    def chain_seal_column_name
      :chain_seal
    end

    def chain_seal_key_provider_object
      nil
    end
  end

  def build_chain_seal!(previous_hash: ChainSeal::GENESIS_PREVIOUS_HASH)
    material = chain_seal_key_material
    seal = ChainSeal.seal(
      payload: chain_seal_payload_value,
      previous_hash: previous_hash,
      kid: material.fetch(:kid),
      private_key: material.fetch(:private_key),
    )
    column_writer = "#{self.class.chain_seal_column_name}="
    public_send(column_writer, seal.compact) if respond_to?(column_writer)
    seal
  end

  def verify_chain_seal!(public_key:)
    ChainSeal.verify(
      compact: public_send(self.class.chain_seal_column_name),
      payload: chain_seal_payload_value,
      public_key: public_key,
    )
  end

  def chain_seal_json
    ChainSeal.parse(public_send(self.class.chain_seal_column_name)).as_json
  end

  private

  def chain_seal_payload_value
    method_name = self.class.chain_seal_payload_method_name
    raise ChainSeal::FormatError, "chain seal payload method is missing" unless respond_to?(method_name)

    public_send(method_name)
  end

  def chain_seal_key_material
    provider = self.class.chain_seal_key_provider_object
    raise ChainSeal::FormatError, "chain seal key provider is missing" if provider.blank?

    material =
      if provider.respond_to?(:call)
        provider.call(self)
      else
        provider
      end

    material.to_h.symbolize_keys
  end
end

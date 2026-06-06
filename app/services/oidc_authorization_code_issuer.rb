# typed: false
# frozen_string_literal: true

class OidcAuthorizationCodeIssuer < ApplicationService
  CLIENT_CODE_TARGETS = {
    "operator" => {
      record_context: OrgTicketRecord,
      code_model: OperatorAuthorizationCode,
      owner_attribute: :staff,
    },
    "staff" => {
      record_context: OrgTicketRecord,
      code_model: OperatorAuthorizationCode,
      owner_attribute: :staff,
    },
    "visitor" => {
      record_context: ComTicketRecord,
      code_model: VisitorAuthorizationCode,
      owner_attribute: :visitor,
    },
    "customer" => {
      record_context: ComTicketRecord,
      code_model: VisitorAuthorizationCode,
      owner_attribute: :visitor,
    },
  }.freeze
  DEFAULT_CODE_TARGET = {
    record_context: AppTicketRecord,
    code_model: ClientAuthorizationCode,
    owner_attribute: :user,
  }.freeze

  def initialize(client:, params:, resource:, auth_method: nil, acr: nil)
    super()
    @client = client
    @params = params
    @resource = resource
    @auth_method = auth_method
    @acr = acr
  end

  def call
    record_context.connected_to(role: :writing) do
      code_model.issue!(owner_attribute => resource, **code_attributes)
    end
  end

  private

  attr_reader :client, :params, :resource, :auth_method, :acr

  def record_context
    code_target.fetch(:record_context)
  end

  def code_model
    code_target.fetch(:code_model)
  end

  def owner_attribute
    code_target.fetch(:owner_attribute)
  end

  def code_target
    CLIENT_CODE_TARGETS.fetch(client.resource_type, DEFAULT_CODE_TARGET)
  end

  def code_attributes
    {
      client_id: params[:client_id],
      redirect_uri: params[:redirect_uri],
      code_challenge: params[:code_challenge],
      code_challenge_method: params[:code_challenge_method],
      scope: params[:scope],
      state: params[:state],
      nonce: params[:nonce],
      auth_method: auth_method,
      acr: acr,
    }
  end
end

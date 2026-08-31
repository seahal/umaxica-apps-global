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

  def initialize(client:, params:, resource:, session_token:, auth_method: nil, acr: nil)
    super()
    @client = client
    @params = params
    @resource = resource
    @session_token = session_token
    @auth_method = auth_method
    @acr = acr
  end

  def call
    validate_session_token!
    record_context.connected_to(role: :writing) do
      code_model.issue!(owner_attribute => resource, session_token_attribute => session_token, **code_attributes)
    end
  end

  private

  attr_reader :client, :params, :resource, :session_token, :auth_method, :acr

  def record_context
    code_target.fetch(:record_context)
  end

  def code_model
    code_target.fetch(:code_model)
  end

  def owner_attribute
    code_target.fetch(:owner_attribute)
  end

  def session_token_attribute
    case code_model.name
    when "OperatorAuthorizationCode" then :operator_token
    when "VisitorAuthorizationCode" then :visitor_token
    else :client_token
    end
  end

  def validate_session_token!
    raise ArgumentError, "session_token is required" if session_token.blank?
    raise ArgumentError, "session token actor mismatch" unless session_token_actor_matches?
    raise ArgumentError,
          "session token is inactive" unless session_token.respond_to?(:currently_usable?) &&
            session_token.currently_usable?
  end

  def session_token_actor_matches?
    case resource
    when ::Operator
      session_token.respond_to?(:staff_id) && session_token.staff_id == resource.id
    when ::Visitor
      session_token.respond_to?(:visitor_id) && session_token.visitor_id == resource.id
    else
      session_token.respond_to?(:user_id) && session_token.user_id == resource.id
    end
  end

  def code_target
    CLIENT_CODE_TARGETS.fetch(resource_type, DEFAULT_CODE_TARGET)
  end

  def resource_type
    case resource
    when ::Operator then "operator"
    when ::Visitor then "visitor"
    else "client"
    end
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

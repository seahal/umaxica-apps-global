# typed: false
# frozen_string_literal: true

class AcmeLogoutTransactionService < ApplicationService
  Result =
    Data.define(:transaction, :status, :error, :error_description) do
      def success? = error.blank?
    end

  def self.issue!(origin_surface:, initiating_client_id:, completion_url:, actor_ref: nil, session_ref: nil,
                  callback_state: nil, now: Time.current, expires_in: 10.minutes)
    unless allowed_completion_url?(origin_surface: origin_surface, completion_url: completion_url)
      return Result.new(
        transaction: nil,
        status: :rejected,
        error: "invalid_request",
        error_description: "completion destination is not allowlisted",
      )
    end

    transaction =
      AppTicketRecord.connected_to(role: :writing) do
        AcmeLogoutTransaction.create!(
          origin_surface: origin_surface.to_s,
          initiating_client_id: initiating_client_id.to_s,
          completion_url: completion_url.to_s,
          actor_ref: actor_ref.to_s.presence,
          session_ref: session_ref.to_s.presence,
          callback_state: callback_state.to_s.presence,
          expected_step: AcmeLogoutTransaction.step_sequence_for(origin_surface).first,
          status: AcmeLogoutTransaction::STATUS_INITIATED,
          expires_at: now + expires_in,
          completed_steps: [],
        )
      end

    Result.new(transaction: transaction, status: :issued, error: nil, error_description: nil)
  end

  def self.find_by_logout_challenge!(logout_challenge)
    AcmeLogoutTransaction.find_by!(public_id: logout_challenge.to_s)
  end

  def self.advance!(logout_challenge:, step:, now: Time.current)
    transaction = find_by_logout_challenge!(logout_challenge)
    transaction.advance_step!(step, now: now)
    Result.new(transaction: transaction.reload, status: :advanced, error: nil, error_description: nil)
  rescue ActiveRecord::RecordNotFound
    Result.new(transaction: nil, status: :missing, error: "not_found", error_description: "logout challenge not found")
  rescue ArgumentError => e
    Result.new(transaction: transaction, status: :rejected, error: "invalid_request", error_description: e.message)
  end

  def self.finalize!(logout_challenge:, now: Time.current)
    transaction = find_by_logout_challenge!(logout_challenge)
    transaction.finalize!(now: now)
    Result.new(transaction: transaction.reload, status: :finalized, error: nil, error_description: nil)
  rescue ActiveRecord::RecordNotFound
    Result.new(transaction: nil, status: :missing, error: "not_found", error_description: "logout challenge not found")
  rescue ArgumentError => e
    Result.new(transaction: transaction, status: :rejected, error: "invalid_request", error_description: e.message)
  end

  def self.allowed_completion_url?(origin_surface:, completion_url:)
    expected = completion_url_for(origin_surface: origin_surface)
    expected == completion_url.to_s
  end

  def self.completion_url_for(origin_surface:, ri: RequestContextContract.default_region)
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    host =
      case origin_surface.to_s
      when "sign" then hosts.sign_service.host
      when "acme" then hosts.acme_service.host
      when "core" then hosts.core_service.host
      when "base" then hosts.base_service.host
      when "palm" then hosts.palm_service.host
      else
        raise ArgumentError, "unsupported logout origin surface: #{origin_surface.inspect}"
      end

    helper = Rails.application.routes.url_helpers
    case origin_surface.to_s
    when "sign"
      helper.complete_sign_app_sign_out_url(ri: ri, host: host, protocol: http_or_https(host))
    when "acme"
      helper.complete_acme_app_sign_out_url(ri: ri, host: host, protocol: http_or_https(host))
    when "core"
      helper.complete_core_app_sign_out_url(ri: ri, host: host, protocol: http_or_https(host))
    when "base"
      helper.complete_base_app_sign_out_url(ri: ri, host: host, protocol: http_or_https(host))
    when "palm"
      helper.palm_app_sign_out_url(host: host, protocol: http_or_https(host))
    end
  end

  def self.http_or_https(host)
    return "https" if Rails.application.config.force_ssl

    "http"
  end
end

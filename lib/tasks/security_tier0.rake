# typed: false
# frozen_string_literal: true

namespace :security do
  desc "Report suspicious client tokens without revoking or deleting them"
  task report_suspicious_user_tokens: :environment do
    result = SecurityTier0SuspiciousUserTokenReport.call

    puts(
      [
        "security_tier0_suspicious_user_tokens",
        "total=#{result[:total]}",
        "suspicious=#{result[:suspicious]}",
        "report_only=#{result[:report_only]}",
      ].join(" "),
    )
  end
end

class SecurityTier0SuspiciousUserTokenReport
  def self.call
    new.call
  end

  def call
    candidates = suspicious_tokens

    candidates.each do |token|
      Rails.logger.warn(
        JitLogEvent.format(
          "security.suspicious_user_token.report_only",
          token_id: token.id,
          user_id: token.user_id,
          status_id: token.user.status_id,
          created_at: token.created_at,
        ),
      )
    end

    {
      total: ClientToken.count,
      suspicious: candidates.count,
      report_only: true,
    }
  end

  private

  def suspicious_tokens
    ClientToken
      .includes(:user)
      .joins(:user)
      .where(clients: { status_id: [ClientStatus::NOTHING, ClientStatus::UNVERIFIED_WITH_SIGN_UP] })
      .order(created_at: :desc)
  end
end

# typed: false
# frozen_string_literal: true

module Preference
  module EmailActions
    extend ActiveSupport::Concern

    include ::EmailValidation
    include ::CloudflareTurnstile

    def new
    end

    def create
      result = cloudflare_turnstile_validation
      unless result["success"]
        flash.now[:alert] = t("base.shared.preference_emails.turnstile_error")
        return render(:new, status: :unprocessable_content)
      end

      email = validate_and_normalize_email(email_param)
      unless email
        flash.now[:alert] = t(preference_email_failure_key(:new))
        return render(:new, status: :unprocessable_content)
      end

      email_record = find_email_record_by_address(email)
      if email_record
        token = Sign::Preference::EmailToken.issue(
          email_record_id: email_record.id,
          email_record_type: email_record.class.name,
          audience: audience_name,
        )
        preference_mailer_class.with(
          preference_request: email_record,
          edit_url: preference_email_edit_url(token),
        ).update_request.deliver_later
      end

      flash[:notice] = t(preference_email_success_key(:new))
      redirect_to(preference_email_new_path)
    end

    def edit
      payload = Sign::Preference::EmailToken.parse(params[:token], audience: audience_name)
      unless payload
        flash[:alert] = t("base.shared.preference_emails.token_invalid")
        return redirect_to(preference_email_new_path)
      end

      @email_record = find_email_record_by_type(payload)
      unless @email_record
        flash[:alert] = t("base.shared.preference_emails.token_invalid")
        return redirect_to(preference_email_new_path)
      end

      @token = params[:token]
    end

    def update
      payload = Sign::Preference::EmailToken.parse(params[:token], audience: audience_name)
      unless payload
        flash[:alert] = t("base.shared.preference_emails.token_invalid")
        return redirect_to(preference_email_new_path)
      end

      @email_record = find_email_record_by_type(payload)
      unless @email_record
        flash[:alert] = t("base.shared.preference_emails.token_invalid")
        return redirect_to(preference_email_new_path)
      end

      if @email_record.update(email_preference_params)
        flash[:notice] = t(preference_email_success_key(:edit))
        redirect_to(preference_email_new_path)
      else
        flash.now[:alert] = t("base.shared.preference_emails.update_failure")
        @token = params[:token]
        render(:edit, status: :unprocessable_content)
      end
    end

    def unsubscribe
      payload = Sign::Preference::EmailToken.parse(params[:token], audience: audience_name)
      unless payload
        flash[:alert] = t("base.shared.preference_emails.token_invalid")
        return redirect_to(preference_email_new_path)
      end

      email_record = find_email_record_by_type(payload)
      unless email_record
        flash[:alert] = t("base.shared.preference_emails.token_invalid")
        return redirect_to(preference_email_new_path)
      end

      email_record.update!(promotional: false, subscribable: false)
      flash[:notice] = t(preference_email_success_key(:edit))
      redirect_to(preference_email_new_path)
    end

    private

    def email_param
      params.fetch(:preference_email, {}).permit(:email)[:email].to_s.strip
    end

    def email_preference_params
      params[preference_email: %i(promotional notifiable subscribable)]
    end

    # Override in each domain controller
    def audience_name
      raise NotImplementedError
    end

    def preference_mailer_class
      raise NotImplementedError
    end

    def find_email_record_by_address(_email)
      raise NotImplementedError
    end

    def find_email_record_by_type(payload)
      email_record_class(payload[:email_record_type]).find_by(id: payload[:email_record_id])
    end

    def email_record_class(type)
      {
        "UserEmail" => UserEmail,
        "CustomerEmail" => CustomerEmail,
      }.fetch(type) { raise ArgumentError, "Unknown email record type: #{type}" }
    end

    def preference_email_failure_key(_action)
      {
        app: "base.app.preference.emails.new.failure",
        com: "base.com.preference.emails.new.failure",
        org: "base.org.preference.emails.new.failure",
      }.fetch(audience_name.to_sym) { "base.shared.preference_emails.failure" }
    end

    def preference_email_success_key(action)
      {
        app: {
          new: "base.app.preference.emails.new.success",
          edit: "base.app.preference.emails.edit.submit",
        },
        com: {
          new: "base.com.preference.emails.new.success",
          edit: "base.com.preference.emails.edit.submit",
        },
        org: {
          new: "base.org.preference.emails.new.success",
          edit: "base.org.preference.emails.edit.submit",
        },
      }.dig(audience_name.to_sym, action) || "base.shared.preference_emails.success"
    end

    def preference_email_new_path
      raise NotImplementedError
    end

    def preference_email_edit_url(_token)
      raise NotImplementedError
    end
  end
end

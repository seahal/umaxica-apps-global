# typed: false
# frozen_string_literal: true

module Sign::Org::UpsHelper
  def sign_org_recruit_contact_link
    preference_params = default_url_options.slice(:ct, :lx, :ri, :tz)
    link_to(
      t("sign.org.ups.new.recruit_link_text"),
      apex_org_root_url(preference_params),
      class: "font-semibold text-slate-900 underline",
    )
  end
end

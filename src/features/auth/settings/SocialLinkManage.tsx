// Connecting and disconnecting one social provider on the app surface.
//
// Whether the provider is linked, and whether disconnecting it would leave the account without
// another way in, are server decisions: the disconnect form is absent while the provider is
// unlinked and disabled while it is the last method, exactly as the ERB screen behaved.
//
// Connecting is a document POST rather than an Inertia visit, because the server answers it with a
// 307 into the provider's OmniAuth request phase, which the browser must follow as a navigation.
import { router } from "@inertiajs/react";
import { useEffect, useState } from "react";

import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import { csrfToken } from "@/lib/csrf";

import type { SettingsLink, SettingsTurnstile } from "./links";

export type SocialLinkManageProps = {
  title: string;
  heading: string;
  description: string;
  back_link: SettingsLink;
  unlink: {
    action: string;
    submit_label: string;
    allowed: boolean;
    blocked_notice: string | null;
  } | null;
  connect: { action: string; label: string } | null;
  turnstile: SettingsTurnstile | null;
};

export default function SocialLinkManage({
  heading,
  description,
  back_link: backLink,
  unlink,
  connect,
  turnstile,
}: SocialLinkManageProps) {
  const [token, setToken] = useState("");
  // The token is read after mount so the component renders the same markup on the server, where
  // there is no document to read the meta tag from.
  const [authenticityToken, setAuthenticityToken] = useState("");

  useEffect(() => {
    setAuthenticityToken(csrfToken());
  }, []);

  const disconnect = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();

    if (!unlink?.allowed) {
      return;
    }

    router.delete(unlink.action, { data: { "cf-turnstile-response": token } });
  };

  return (
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <a href={backLink.href}>{backLink.label}</a>

      <div>
        <h3>{heading}</h3>
        <p>{description}</p>

        {unlink ? (
          <>
            <form onSubmit={disconnect}>
              {turnstile ? (
                <TurnstileWidget
                  site_key={turnstile.site_key}
                  mode={turnstile.mode}
                  action={turnstile.action}
                  cdata={turnstile.cdata}
                  onToken={setToken}
                />
              ) : null}
              <input
                type="submit"
                value={unlink.submit_label}
                disabled={!unlink.allowed}
              />
            </form>
            {unlink.blocked_notice ? <p>{unlink.blocked_notice}</p> : null}
          </>
        ) : null}

        {connect ? (
          <form
            method="post"
            action={connect.action}
          >
            <input
              type="hidden"
              name="authenticity_token"
              value={authenticityToken}
            />
            <input
              type="submit"
              value={connect.label}
            />
          </form>
        ) : null}
      </div>
    </section>
  );
}

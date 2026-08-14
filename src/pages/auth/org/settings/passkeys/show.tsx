// One registered passkey, with the same DELETE form the index row carries.
import { csrfToken } from "@/features/auth/csrf";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";

type TurnstileConfiguration = {
  site_key: string;
  mode: "render" | "execute";
  action: string | null;
  cdata: string | null;
};

export type OrgPasskeySettingsShowProps = {
  title: string;
  back_link: { label: string; href: string };
  details: { term: string; value: string }[];
  edit_link: { label: string; href: string };
  destroy_action: string;
  destroy_label: string;
  destroy_confirm: string;
  turnstile: TurnstileConfiguration;
};

export default function OrgPasskeySettingsShow({
  title,
  back_link: backLink,
  details,
  edit_link: editLink,
  destroy_action: destroyAction,
  destroy_label: destroyLabel,
  destroy_confirm: destroyConfirm,
  turnstile,
}: OrgPasskeySettingsShowProps) {
  return (
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <a href={backLink.href}>{backLink.label}</a>

      <div>
        <h3>{title}</h3>
        <dl>
          {details.map((detail) => (
            <div key={detail.term}>
              <dt>{detail.term}</dt>
              <dd>{detail.value}</dd>
            </div>
          ))}
        </dl>
      </div>

      <div>
        <a href={editLink.href}>{editLink.label}</a>
        <form
          action={destroyAction}
          method="post"
          onSubmit={(event) => {
            if (!window.confirm(destroyConfirm)) {
              event.preventDefault();
            }
          }}
        >
          <input
            type="hidden"
            name="_method"
            value="delete"
            readOnly
          />
          <input
            type="hidden"
            name="authenticity_token"
            value={csrfToken()}
            readOnly
          />
          <TurnstileWidget
            site_key={turnstile.site_key}
            mode={turnstile.mode}
            action={turnstile.action}
            cdata={turnstile.cdata}
          />
          <input
            type="submit"
            value={destroyLabel}
          />
        </form>
      </div>
    </section>
  );
}

// One registered passkey in detail.
//
// The rows are built on the server, so the formatting, the translation and the "unknown
// authenticator" fallback stay in one place. This screen reads; renaming and removal live behind
// the edit link.
import type { SettingsLink } from "@/features/auth/settings/links";

type Props = {
  title: string;
  description: string;
  back_link: SettingsLink;
  passkey_description: string | null;
  details: { key: string; label: string; value: string }[];
  edit_link: SettingsLink;
};

export default function PasskeysShow({
  title,
  description,
  back_link: backLink,
  passkey_description: passkeyDescription,
  details,
  edit_link: editLink,
}: Props) {
  return (
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <a href={backLink.href}>{backLink.label}</a>

      <div>
        <h3>{title}</h3>
        <p>{description}</p>
      </div>

      <div>
        <h3>{passkeyDescription}</h3>
        <dl>
          {details.map((detail) => (
            <div key={detail.key}>
              <dt>{detail.label}</dt>
              <dd>{detail.value}</dd>
            </div>
          ))}
        </dl>
      </div>

      <a href={editLink.href}>{editLink.label}</a>
    </section>
  );
}

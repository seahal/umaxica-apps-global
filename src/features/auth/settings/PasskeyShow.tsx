// One registered passkey in detail.
//
// The rows are built on the server so the formatting, the translation and the "unknown
// authenticator" fallback stay in one place.
import PasskeyDeleteButton, {
  type TurnstileConfiguration,
} from "@/features/auth/settings/PasskeyDeleteButton";

export type PasskeyDetail = {
  key: string;
  label: string;
  value: string;
};

export type PasskeyShowProps = {
  title: string;
  back_link: { label: string; href: string };
  details: PasskeyDetail[];
  edit_link: { label: string; href: string };
  destroy_href: string;
  destroy_label: string;
  confirm_message: string;
  turnstile: TurnstileConfiguration;
};

export default function PasskeyShow({
  title,
  back_link: backLink,
  details,
  edit_link: editLink,
  destroy_href: destroyHref,
  destroy_label: destroyLabel,
  confirm_message: confirmMessage,
  turnstile,
}: PasskeyShowProps) {
  return (
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <a href={backLink.href}>{backLink.label}</a>

      <div>
        <h3>{title}</h3>
        <dl>
          {details.map((detail) => (
            <div key={detail.key}>
              <dt>{detail.label}</dt>
              <dd>{detail.value}</dd>
            </div>
          ))}
        </dl>

        <div>
          <a href={editLink.href}>{editLink.label}</a>
          <PasskeyDeleteButton
            action={destroyHref}
            label={destroyLabel}
            confirm_message={confirmMessage}
            turnstile={turnstile}
          />
        </div>
      </div>
    </section>
  );
}

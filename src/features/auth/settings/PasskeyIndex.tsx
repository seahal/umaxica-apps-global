// The registered passkeys of one actor.
//
// Every row arrives serialized: a public id, the description the actor gave, a formatted timestamp
// and the URLs for the actions this actor may take. No model object and no raw credential material
// crosses the boundary.
import PasskeyDeleteButton, {
  type TurnstileConfiguration,
} from "@/features/auth/settings/PasskeyDeleteButton";

export type PasskeyRow = {
  public_id: string;
  description: string | null;
  created_at: string;
  edit_href: string;
  destroy_href: string;
};

export type PasskeyIndexProps = {
  title: string;
  add_link: { label: string; href: string };
  back_link: { label: string; href: string };
  columns: { description: string; created_at: string; actions: string };
  passkeys: PasskeyRow[];
  empty_message: string;
  edit_label: string;
  destroy_label: string;
  confirm_message: string;
  turnstile: TurnstileConfiguration;
};

export default function PasskeyIndex({
  title,
  add_link: addLink,
  back_link: backLink,
  columns,
  passkeys,
  empty_message: emptyMessage,
  edit_label: editLabel,
  destroy_label: destroyLabel,
  confirm_message: confirmMessage,
  turnstile,
}: PasskeyIndexProps) {
  return (
    <section className="mx-auto flex w-full max-w-3xl flex-col gap-6 p-6">
      <div>
        <h1>{title}</h1>
        <a href={addLink.href}>{addLink.label}</a>
      </div>

      <table>
        <thead>
          <tr>
            <th scope="col">{columns.description}</th>
            <th scope="col">{columns.created_at}</th>
            <th scope="col">{columns.actions}</th>
          </tr>
        </thead>
        <tbody>
          {passkeys.map((passkey) => (
            <tr key={passkey.public_id}>
              <td>{passkey.description}</td>
              <td>{passkey.created_at}</td>
              <td>
                <a href={passkey.edit_href}>{editLabel}</a>
                <PasskeyDeleteButton
                  action={passkey.destroy_href}
                  label={destroyLabel}
                  confirm_message={confirmMessage}
                  turnstile={turnstile}
                />
              </td>
            </tr>
          ))}
          {passkeys.length === 0 ? (
            <tr>
              <td colSpan={3}>{emptyMessage}</td>
            </tr>
          ) : null}
        </tbody>
      </table>

      <a href={backLink.href}>{backLink.label}</a>
    </section>
  );
}

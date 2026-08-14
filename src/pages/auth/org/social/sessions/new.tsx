// The Microsoft Entra ID cushion page of the org sign-in ceremony.
//
// Availability is decided on the server: when the kill switch is on, the notice arrives and the
// form does not, so the page cannot offer a ceremony the request phase would refuse. The form is a
// document POST because the browser has to follow the 307 and then the redirect to Entra.
import { csrfToken } from "@/features/auth/csrf";

export type OrgEntraSessionEntryProps = {
  title: string;
  unavailable_notice: string | null;
  form: { action: string; submit_label: string } | null;
};

export default function OrgEntraSessionEntry({
  title,
  unavailable_notice: unavailableNotice,
  form,
}: OrgEntraSessionEntryProps) {
  return (
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <div>
        <h1>{title}</h1>
      </div>

      {unavailableNotice ? (
        <div role="alert">
          <p>{unavailableNotice}</p>
        </div>
      ) : null}

      {form ? (
        <form
          action={form.action}
          method="post"
        >
          <input
            type="hidden"
            name="authenticity_token"
            value={csrfToken()}
            readOnly
          />
          <div>
            <input
              type="submit"
              className="btn-entra"
              value={form.submit_label}
            />
          </div>
        </form>
      ) : null}
    </section>
  );
}

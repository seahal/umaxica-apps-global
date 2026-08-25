// The Microsoft Entra ID cushion page of the org sign-in ceremony.
//
// Availability is decided on the server: when the kill switch is on, the notice arrives and the
// form does not, so the page cannot offer a ceremony the request phase would refuse. The form is a
// document POST because the browser has to follow the 307 and then the redirect to Entra.
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import { csrfToken } from "@/lib/csrf";

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
    <Page
      title={title}
      width="narrow"
    >
      <ErrorList errors={unavailableNotice === null ? [] : [unavailableNotice]} />

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
          {/* The provider button's wording and shape are constrained by
              docs/reference/third-party-sign-in-button-requirements.md, so it keeps its own class
              rather than taking the application button's appearance. */}
          <input
            type="submit"
            className="btn-entra"
            value={form.submit_label}
          />
        </form>
      ) : null}
    </Page>
  );
}

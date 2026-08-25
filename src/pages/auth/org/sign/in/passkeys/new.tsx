// Passkey sign-in for operators.
//
// The identifier is the operator's public id, and the ceremony runs against the same options and
// verification endpoints, with the same rate limits, that the Stimulus controller used.
import Page from "@/components/ui/Page";
import PasskeyAuthenticationPanel, {
  type PasskeyAuthenticationPanelProps,
} from "@/features/auth/passkeys/PasskeyAuthenticationPanel";

export type OrgPasskeySignInPageProps = {
  title: string;
  description: string;
  panel: PasskeyAuthenticationPanelProps;
  back_link: { label: string; href: string };
};

export default function OrgPasskeySignInPage({
  title,
  description,
  panel,
  back_link: backLink,
}: OrgPasskeySignInPageProps) {
  return (
    <Page
      title={title}
      description={description}
      up={backLink}
      width="narrow"
    >
      <PasskeyAuthenticationPanel {...panel} />
    </Page>
  );
}

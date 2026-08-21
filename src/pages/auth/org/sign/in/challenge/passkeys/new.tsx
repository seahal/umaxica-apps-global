// The passkey second factor of the org sign-in ceremony.
import Page from "@/components/ui/Page";
import StepUpPasskeyForm, {
  type StepUpPasskeyFormProps,
} from "@/features/auth/passkeys/StepUpPasskeyForm";

export type OrgMfaPasskeyPageProps = {
  title: string;
  description: string;
  form: StepUpPasskeyFormProps;
  back_link: { label: string; href: string };
};

export default function OrgMfaPasskeyPage({
  title,
  description,
  form,
  back_link: backLink,
}: OrgMfaPasskeyPageProps) {
  return (
    <Page
      title={title}
      description={description}
      up={backLink}
      width="narrow"
    >
      <StepUpPasskeyForm {...form} />
    </Page>
  );
}

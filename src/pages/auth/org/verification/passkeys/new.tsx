// The passkey step-up challenge for an already signed-in operator.
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import StepUpPasskeyForm, {
  type StepUpPasskeyFormProps,
} from "@/features/auth/passkeys/StepUpPasskeyForm";

export type OrgVerificationPasskeyPageProps = {
  title: string;
  description: string;
  errors_sentence: string | null;
  form: StepUpPasskeyFormProps;
  back_link: { label: string; href: string };
};

export default function OrgVerificationPasskeyPage({
  title,
  description,
  errors_sentence: errorsSentence,
  form,
  back_link: backLink,
}: OrgVerificationPasskeyPageProps) {
  return (
    <Page
      title={title}
      description={description}
      up={backLink}
      width="narrow"
    >
      <ErrorList errors={errorsSentence === null ? [] : [errorsSentence]} />

      <StepUpPasskeyForm {...form} />
    </Page>
  );
}

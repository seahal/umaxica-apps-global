// The passkey step-up challenge for an already signed-in operator.
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
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <h1>{title}</h1>
      <p>{description}</p>

      {errorsSentence ? <div role="alert">{errorsSentence}</div> : null}

      <StepUpPasskeyForm {...form} />

      <div>
        <a href={backLink.href}>{backLink.label}</a>
      </div>
    </section>
  );
}

// The passkey second factor of the org sign-in ceremony.
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
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <h1>{title}</h1>
      <p>{description}</p>

      <StepUpPasskeyForm {...form} />

      <div>
        <a href={backLink.href}>{backLink.label}</a>
      </div>
    </section>
  );
}

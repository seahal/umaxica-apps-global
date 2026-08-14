// The org sign-up entry screen.
//
// The org surface has no self-service registration: an operator is recruited and then invited, so
// the page is a prompt with a contact link rather than a list of registration methods. When the
// kill switch has suspended sign-up the server sends the notice alone.
type SignUpLink = {
  label: string;
  href: string;
};

export type OrgSignUpEntryProps = {
  title: string;
  description: string | null;
  suspended_notice: string | null;
  recruit: { prompt: string; label: string; href: string } | null;
  sign_in_link: SignUpLink | null;
  back_to_root: SignUpLink | null;
};

export default function OrgSignUpEntry({
  title,
  description,
  suspended_notice: suspendedNotice,
  recruit,
  sign_in_link: signInLink,
  back_to_root: backToRoot,
}: OrgSignUpEntryProps) {
  if (suspendedNotice) {
    return (
      <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
        <div
          role="alert"
          data-test-id="sign-up-suspended"
        >
          <p>{suspendedNotice}</p>
        </div>
      </section>
    );
  }

  return (
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <div>
        <h1>{title}</h1>
        {description ? <p>{description}</p> : null}
      </div>

      <div>
        {recruit ? (
          <div>
            <p>{recruit.prompt}</p>
            <a
              className="font-semibold text-slate-900 underline"
              href={recruit.href}
            >
              {recruit.label}
            </a>
          </div>
        ) : null}

        {signInLink ? (
          <div>
            <a href={signInLink.href}>{signInLink.label}</a>
          </div>
        ) : null}

        {backToRoot ? (
          <div>
            <a href={backToRoot.href}>
              <span>{backToRoot.label}</span>
            </a>
          </div>
        ) : null}
      </div>
    </section>
  );
}

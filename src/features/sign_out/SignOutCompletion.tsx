// The sign-out completion screen, replacing `app/views/base/shared/sign_outs/complete.html.erb`.

import ButtonLink from "@/components/ui/ButtonLink";
import Page from "@/components/ui/Page";

export type SignOutCompletionProps = {
  title: string;
  /** Absent when the server has no expiry to report. */
  description: string | null;
  home_link: { label: string; href: string };
};

export default function SignOutCompletion({
  title,
  description,
  home_link: homeLink,
}: SignOutCompletionProps) {
  return (
    <Page
      title={title}
      {...(description === null ? {} : { description })}
      width="narrow"
    >
      <p>
        <ButtonLink
          href={homeLink.href}
          inertia
        >
          {homeLink.label}
        </ButtonLink>
      </p>
    </Page>
  );
}

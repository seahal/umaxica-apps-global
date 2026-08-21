// The org sign-in entry screen.
//
// It is not `AuthMethodChoice`, because one of the three methods is not a link: Entra ID starts
// with a POST to the surface ceremony endpoint, which prepares the ceremony and hands the same POST
// to the OmniAuth request phase with a 307. The button wording and shape are constrained by
// docs/reference/third-party-sign-in-button-requirements.md.
import Page from "@/components/ui/Page";
import TextLink from "@/components/ui/TextLink";
import { csrfToken } from "@/lib/csrf";

type SignInMethod = {
  key: string;
  kind: "link" | "provider";
  label: string;
  href: string;
};

type SignInLink = {
  label: string;
  href: string;
};

export type OrgSignInEntryProps = {
  title: string;
  description: string;
  methods: SignInMethod[];
  registration_link: SignInLink | null;
  back_to_root: SignInLink;
};

export default function OrgSignInEntry({
  title,
  description,
  methods,
  registration_link: registrationLink,
  back_to_root: backToRoot,
}: OrgSignInEntryProps) {
  return (
    <Page
      title={title}
      description={description}
      up={backToRoot}
    >
      <ul className="flex flex-col gap-3">
        {methods.map((method) =>
          method.kind === "provider" ? (
            <li key={method.key}>
              {/* A document POST: the browser has to follow the 307 and then the cross-origin
                  redirect to the provider, which an Inertia visit cannot do. */}
              <form
                action={method.href}
                method="post"
                className="social-provider-form"
              >
                <input
                  type="hidden"
                  name="authenticity_token"
                  value={csrfToken()}
                  readOnly
                />
                <input
                  type="submit"
                  className={`social-provider-button social-provider-button--${method.key}`}
                  value={method.label}
                />
              </form>
            </li>
          ) : (
            <li key={method.key}>
              <a
                href={method.href}
                className="flex items-center justify-between gap-3 rounded-lg border border-line
                  bg-surface px-4 py-3 text-sm font-medium text-fg hover:bg-surface-muted"
              >
                <span>{method.label}</span>
                <span
                  aria-hidden="true"
                  className="text-fg-muted"
                >
                  &rarr;
                </span>
              </a>
            </li>
          ),
        )}
      </ul>

      {registrationLink ? (
        <p className="text-sm">
          <TextLink href={registrationLink.href}>{registrationLink.label}</TextLink>
        </p>
      ) : null}
    </Page>
  );
}

// The org sign-in entry screen.
//
// It is not `AuthMethodChoice`, because one of the three methods is not a link: Entra ID starts
// with a POST to the surface ceremony endpoint, which prepares the ceremony and hands the same POST
// to the OmniAuth request phase with a 307. The button wording and shape are constrained by
// docs/reference/third-party-sign-in-button-requirements.md.
import { csrfToken } from "@/features/auth/csrf";

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
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <div>
        <h1>{title}</h1>
        <p>{description}</p>
      </div>

      <ul className="sign-in-methods">
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
              <a href={method.href}>{method.label}</a>
            </li>
          ),
        )}
      </ul>

      <div>
        {registrationLink ? <a href={registrationLink.href}>{registrationLink.label}</a> : null}

        <div>
          <a href={backToRoot.href}>
            <span>{backToRoot.label}</span>
          </a>
        </div>
      </div>
    </section>
  );
}

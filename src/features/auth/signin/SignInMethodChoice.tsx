// The app-surface sign-in entry screen: pick a credential method, or hand off to a social provider.
//
// Which methods exist and where they lead are server decisions, so each entry arrives with a
// finished label and a finished URL. The provider buttons are separate native forms rather than
// links because the hand-off is a POST.
import SocialProviderButton, { type SocialProvider } from "./SocialProviderButton";

export type SignInMethodLink = {
  key: string;
  label: string;
  href: string;
};

export type SignInMethodChoiceProps = {
  title: string;
  description: string;
  methods: SignInMethodLink[];
  social_providers: SocialProvider[];
  registration_link: SignInMethodLink;
};

export default function SignInMethodChoice({
  title,
  description,
  methods,
  social_providers: socialProviders,
  registration_link: registrationLink,
}: SignInMethodChoiceProps) {
  return (
    <section>
      <h1>{title}</h1>
      <p>{description}</p>

      <ul>
        {methods.map((method) => (
          <li key={method.key}>
            {/* Document visits: each method starts a ceremony behind its own guards. */}
            <a href={method.href}>{method.label}</a>
          </li>
        ))}
      </ul>

      <ul className="social-provider-buttons">
        {socialProviders.map((provider) => (
          <li key={provider.key}>
            <SocialProviderButton provider={provider} />
          </li>
        ))}
      </ul>

      <a href={registrationLink.href}>{registrationLink.label}</a>
    </section>
  );
}

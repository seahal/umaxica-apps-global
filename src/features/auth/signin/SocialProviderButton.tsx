// Provider sign-in button, the React equivalent of `app/views/auth/shared/_social_provider_button`.
//
// It posts natively to the surface ceremony endpoint, which hands the same POST to the OmniAuth
// request phase with a 307; a document submission is required so the browser can follow that and
// then the cross-origin redirect to the provider. The form carries a global authenticity token
// because the token is verified twice, at two different paths.
//
// The artwork and wording are constrained by
// docs/reference/third-party-sign-in-button-requirements.md. Do not substitute a custom design,
// custom wording, or redrawn logo artwork. The server decides which artwork exists: Google sends
// its official whole-button artwork (which carries its own English wording, so the accessible name
// matches the artwork rather than the locale), Apple sends the official logo pair only when the
// deployment carries it, and any other provider sends neither and renders a title-only button.
export type SocialProviderArtwork = {
  light: string;
  dark: string;
  width: number;
  height: number;
};

export type SocialProviderLogos = {
  white: string;
  black: string;
  width: number;
  height: number;
};

export type SocialProvider = {
  key: string;
  label: string;
  action: string;
  /**
   * Global authenticity token for this native POST, the same one the ERB form embedded. It is
   * verified twice - here and again at the OmniAuth request phase, which sits at another path.
   */
  authenticity_token: string;
  aria_label: string | null;
  artwork: SocialProviderArtwork | null;
  logos: SocialProviderLogos | null;
};

export default function SocialProviderButton({ provider }: { provider: SocialProvider }) {
  return (
    <form
      action={provider.action}
      method="post"
      data-turbo="false"
      className="social-provider-form"
    >
      <input
        type="hidden"
        name="authenticity_token"
        value={provider.authenticity_token}
        readOnly
      />

      {provider.artwork ? (
        <button
          type="submit"
          className={`social-provider-button social-provider-button--${provider.key}`}
          aria-label={provider.aria_label ?? provider.label}
        >
          <img
            src={provider.artwork.light}
            alt=""
            width={provider.artwork.width}
            height={provider.artwork.height}
            className="social-provider-button__art social-provider-button__art--light"
          />
          <img
            src={provider.artwork.dark}
            alt=""
            width={provider.artwork.width}
            height={provider.artwork.height}
            className="social-provider-button__art social-provider-button__art--dark"
          />
        </button>
      ) : (
        <button
          type="submit"
          className={`social-provider-button social-provider-button--${provider.key}`}
        >
          {provider.logos ? (
            <>
              <img
                src={provider.logos.white}
                alt=""
                width={provider.logos.width}
                height={provider.logos.height}
                className={`social-provider-button__${provider.key}-logo social-provider-button__${provider.key}-logo--white`}
              />
              <img
                src={provider.logos.black}
                alt=""
                width={provider.logos.width}
                height={provider.logos.height}
                className={`social-provider-button__${provider.key}-logo social-provider-button__${provider.key}-logo--black`}
              />
            </>
          ) : null}
          <span className={`social-provider-button__${provider.key}-title`}>{provider.label}</span>
        </button>
      )}
    </form>
  );
}

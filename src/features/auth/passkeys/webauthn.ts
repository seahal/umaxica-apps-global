// Typed WebAuthn glue for the migrated auth pages.
//
// The encoding rules are the ones the Stimulus passkey controllers already used, and they must stay
// byte-for-byte identical because the server verifies the resulting JSON. Option normalisation is
// delegated to `src/controllers/webauthn_utils.ts` so there is one implementation of it, not two.
import { normalizeCreationOptions, normalizeRequestOptions } from "@/controllers/webauthn_utils";

export type SerializedCredential = {
  id: string;
  rawId: string;
  type: string;
  authenticatorAttachment: string | null;
  response: Record<string, string | string[] | null>;
  clientExtensionResults: AuthenticationExtensionsClientOutputs;
};

export function bufferToBase64url(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  let binary = "";
  // Iterated by value rather than by index: a typed array yields numbers directly, so there is no
  // possibly-absent element to account for.
  for (const byte of bytes) {
    binary += String.fromCodePoint(byte);
  }
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

// `navigator.credentials` answers the base `Credential` type, and an authenticator may in
// principle answer another kind of it. These predicates check the parts this module reads instead
// of asserting the WebAuthn shape onto whatever came back.
type AssertionCredential = Credential & {
  rawId: ArrayBuffer;
  authenticatorAttachment: string | null;
  response: AuthenticatorAssertionResponse;
  getClientExtensionResults: () => AuthenticationExtensionsClientOutputs;
};

export type AttestationCredential = Credential & {
  rawId: ArrayBuffer;
  authenticatorAttachment: string | null;
  response: AuthenticatorAttestationResponse;
  getClientExtensionResults: () => AuthenticationExtensionsClientOutputs;
};

function hasCredentialParts(credential: object, responseKeys: string[]): boolean {
  if (!("rawId" in credential) || !("response" in credential)) {
    return false;
  }

  const { response } = credential;
  if (typeof response !== "object" || response === null) {
    return false;
  }

  return responseKeys.every((key) => key in response);
}

function isAssertionCredential(credential: Credential): credential is AssertionCredential {
  return hasCredentialParts(credential, ["clientDataJSON", "authenticatorData", "signature"]);
}

export function isAttestationCredential(credential: object): credential is AttestationCredential {
  return hasCredentialParts(credential, ["clientDataJSON", "attestationObject"]);
}

export function passkeysSupported(): boolean {
  return typeof window !== "undefined" && Boolean(window.PublicKeyCredential);
}

/** Runs `navigator.credentials.get` and serializes the assertion the way the server expects. */
export async function getAssertion(options: unknown): Promise<SerializedCredential> {
  const publicKey = normalizeRequestOptions(options);
  const credential = await navigator.credentials.get({ publicKey });

  if (!credential) {
    throw new Error("No credential was returned by the authenticator");
  }

  if (!isAssertionCredential(credential)) {
    throw new Error("The authenticator returned a credential that is not a WebAuthn assertion");
  }

  const assertion = credential;
  const { response } = assertion;

  return {
    id: assertion.id,
    rawId: bufferToBase64url(assertion.rawId),
    type: assertion.type,
    authenticatorAttachment: assertion.authenticatorAttachment ?? null,
    response: {
      clientDataJSON: bufferToBase64url(response.clientDataJSON),
      authenticatorData: bufferToBase64url(response.authenticatorData),
      signature: bufferToBase64url(response.signature),
      userHandle: response.userHandle ? bufferToBase64url(response.userHandle) : null,
    },
    clientExtensionResults: assertion.getClientExtensionResults(),
  };
}

/** Runs `navigator.credentials.create` and serializes the attestation the way the server expects. */
export async function createCredential(options: unknown): Promise<SerializedCredential> {
  const publicKey = normalizeCreationOptions(options);
  const credential = await navigator.credentials.create({ publicKey });

  if (!credential) {
    throw new Error("No credential was returned by the authenticator");
  }

  if (!isAttestationCredential(credential)) {
    throw new Error("The authenticator returned a credential that is not a WebAuthn attestation");
  }

  const attestation = credential;
  const { response } = attestation;

  return {
    id: attestation.id,
    rawId: bufferToBase64url(attestation.rawId),
    type: attestation.type,
    authenticatorAttachment: attestation.authenticatorAttachment ?? null,
    response: {
      clientDataJSON: bufferToBase64url(response.clientDataJSON),
      attestationObject: bufferToBase64url(response.attestationObject),
      // Reported when the authenticator supports it, which lets the server offer the right
      // transport hints on a later assertion.
      transports: typeof response.getTransports === "function" ? response.getTransports() : [],
    },
    clientExtensionResults: attestation.getClientExtensionResults(),
  };
}

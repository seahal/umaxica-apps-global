// Typed WebAuthn glue for the migrated auth pages.
//
// The encoding rules are the ones the Stimulus passkey controllers already used, and they must stay
// byte-for-byte identical because the server verifies the resulting JSON. Option normalisation is
// delegated to `src/controllers/webauthn_utils.js` so there is one implementation of it, not two.
import { normalizePublicKeyOptions } from "@/controllers/webauthn_utils";

export type SerializedCredential = {
  id: string;
  rawId: string;
  type: string;
  authenticatorAttachment: string | null;
  response: Record<string, string | null>;
  clientExtensionResults: AuthenticationExtensionsClientOutputs;
};

export function bufferToBase64url(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  let binary = "";
  for (let index = 0; index < bytes.length; index += 1) {
    binary += String.fromCharCode(bytes[index]);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}

export function passkeysSupported(): boolean {
  return typeof window !== "undefined" && Boolean(window.PublicKeyCredential);
}

/** Runs `navigator.credentials.get` and serializes the assertion the way the server expects. */
export async function getAssertion(options: unknown): Promise<SerializedCredential> {
  const publicKey = normalizePublicKeyOptions(options);
  const credential = await navigator.credentials.get({ publicKey });

  if (!credential) {
    throw new Error("No credential was returned by the authenticator");
  }

  const assertion = credential as PublicKeyCredential;
  const response = assertion.response as AuthenticatorAssertionResponse;

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
  const publicKey = normalizePublicKeyOptions(options);
  const credential = await navigator.credentials.create({ publicKey });

  if (!credential) {
    throw new Error("No credential was returned by the authenticator");
  }

  const attestation = credential as PublicKeyCredential;
  const response = attestation.response as AuthenticatorAttestationResponse;

  return {
    id: attestation.id,
    rawId: bufferToBase64url(attestation.rawId),
    type: attestation.type,
    authenticatorAttachment: attestation.authenticatorAttachment ?? null,
    response: {
      clientDataJSON: bufferToBase64url(response.clientDataJSON),
      attestationObject: bufferToBase64url(response.attestationObject),
    },
    clientExtensionResults: attestation.getClientExtensionResults(),
  };
}

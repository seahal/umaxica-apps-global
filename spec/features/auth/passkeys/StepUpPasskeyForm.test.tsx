import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

// The React port of `step_up_passkey_controller.js`. The ceremony itself (normalising options,
// calling the credential API, encoding the assertion) lives in `@/features/auth/passkeys/webauthn`
// and is covered independently; what belongs here is what this component decides: the
// preconditions it refuses on, the hidden field it fills, and that it submits the form.
import StepUpPasskeyForm from "@/features/auth/passkeys/StepUpPasskeyForm";

import { requireInput } from "../../../support/dom";
import {
  REQUEST_OPTIONS,
  assertionCredential,
  credentialError,
  stubCredentialsApi,
} from "../../../support/webauthn";

declare global {
  // React reads this flag off the global object to decide whether `act` is allowed.
  var IS_REACT_ACT_ENVIRONMENT: boolean;
}
globalThis.IS_REACT_ACT_ENVIRONMENT = true;

const NOOP = () => {};

let container: HTMLDivElement;
let root: Root;

const mount = (element: React.ReactElement) => {
  container = document.createElement("div");
  document.body.append(container);
  root = createRoot(container);
  act(() => {
    root.render(element);
  });
};

const click = (selector: string) => {
  const button = container.querySelector<HTMLButtonElement>(selector);
  expect(button).not.toBeNull();
  act(() => {
    button?.dispatchEvent(new MouseEvent("click", { bubbles: true }));
  });
};

const flush = async () => {
  await act(async () => {
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
  });
};

let submitted: number;
let submittedCredentialJson: string | null;
let credentials: ReturnType<typeof stubCredentialsApi>;

beforeEach(() => {
  document.head.innerHTML = '<meta name="csrf-token" content="a-token">';
  credentials = stubCredentialsApi();
  submitted = 0;
  submittedCredentialJson = null;
  // A real `requestSubmit()` reads the form's fields synchronously at the moment it is called, so
  // that is also where this stub has to read them: React's own state flush for the "verifying"
  // status runs asynchronously afterwards and resets this uncontrolled field's DOM value to its
  // `defaultValue`, same as it would after any browser had already read it.
  HTMLFormElement.prototype.requestSubmit = vi.fn(function (this: HTMLFormElement) {
    submitted += 1;
    submittedCredentialJson =
      this.querySelector<HTMLInputElement>("input[name='verification[credential_json]']")?.value ??
      null;
  });
});

afterEach(() => {
  root.unmount();
  container.remove();
  vi.unstubAllGlobals();
});

const PROPS = {
  action: "/verification",
  param_scope: "verification",
  challenge_id: "challenge-123",
  request_options: REQUEST_OPTIONS,
  submit_label: "Continue",
};

describe("StepUpPasskeyForm", () => {
  it("carries the CSRF token and the challenge id in hidden fields", () => {
    mount(<StepUpPasskeyForm {...PROPS} />);

    expect(requireInput(container, "input[name='authenticity_token']").value).toBe("a-token");
    expect(requireInput(container, "input[name='verification[challenge_id]']").value).toBe(
      "challenge-123",
    );
  });

  it("fills the credential field and submits the form", async () => {
    credentials.get.mockResolvedValue(assertionCredential());
    mount(<StepUpPasskeyForm {...PROPS} />);

    click("button");
    await act(async () => {
      await vi.waitFor(() => expect(submitted).toBe(1));
    });

    expect(JSON.parse(String(submittedCredentialJson))).toMatchObject({ id: "cred-id" });
  });

  it("refuses when the browser does not support passkeys", async () => {
    vi.stubGlobal("PublicKeyCredential", undefined);
    mount(<StepUpPasskeyForm {...PROPS} />);

    click("button");
    await flush();

    expect(container.querySelector("[role='alert']")?.textContent).toBe(
      "このブラウザはPasskeyに対応していません",
    );
    expect(credentials.get).not.toHaveBeenCalled();
  });

  it("refuses when the server issued no options", async () => {
    mount(
      <StepUpPasskeyForm
        {...PROPS}
        request_options={null}
      />,
    );

    click("button");
    await flush();

    expect(container.querySelector("[role='alert']")?.textContent).toBe(
      "認証オプションの取得に失敗しました",
    );
  });

  it("refuses when the server issued no challenge id", async () => {
    mount(
      <StepUpPasskeyForm
        {...PROPS}
        challenge_id=""
      />,
    );

    click("button");
    await flush();

    expect(container.querySelector("[role='alert']")?.textContent).toBe(
      "認証オプションの取得に失敗しました",
    );
  });

  it("does nothing when the component unmounts before the ceremony resolves", async () => {
    let resolveCredential: (value: Credential | PromiseLike<Credential | null> | null) => void =
      NOOP;
    credentials.get.mockReturnValue(
      new Promise((resolve) => {
        resolveCredential = resolve;
      }),
    );
    mount(<StepUpPasskeyForm {...PROPS} />);

    click("button");
    act(() => {
      root.unmount();
    });

    expect(() => {
      resolveCredential(assertionCredential());
    }).not.toThrow();
    await flush();

    expect(submitted).toBe(0);
  });

  it("reports a cancelled ceremony in the visitor's terms", async () => {
    credentials.get.mockRejectedValue(credentialError("NotAllowedError", "Cancelled"));
    mount(<StepUpPasskeyForm {...PROPS} />);

    click("button");
    await flush();

    expect(container.querySelector("[role='alert']")?.textContent).toBe(
      "認証がキャンセルされました",
    );
    expect(submitted).toBe(0);
  });
});

import { afterEach, describe, expect, test } from "vitest";

import { csrfToken, preferenceQueryParameters } from "@/lib/request";

afterEach(() => {
  document.head.innerHTML = "";
  window.history.replaceState({}, "", "/");
});

describe("csrfToken", () => {
  test("returns the token published by the layout meta tag", () => {
    document.head.innerHTML = '<meta name="csrf-token" content="token-value">';

    expect(csrfToken()).toBe("token-value");
  });

  test("returns an empty string when the meta tag is absent", () => {
    expect(csrfToken()).toBe("");
  });
});

describe("preferenceQueryParameters", () => {
  test("returns the preference parameters present on the URL in declaration order", () => {
    window.history.replaceState({}, "", "/?tz=asia%2Ftokyo&lx=en&ri=jp&ct=dr");

    expect(preferenceQueryParameters()).toEqual([
      ["ri", "jp"],
      ["lx", "en"],
      ["ct", "dr"],
      ["tz", "asia/tokyo"],
    ]);
  });

  // Parameters outside the preference contract belong to the page, not to the preference context,
  // so they must not be forwarded to the preference endpoints.
  test("drops parameters that are not part of the preference contract", () => {
    window.history.replaceState({}, "", "/?ri=jp&rt=ignored");

    expect(preferenceQueryParameters()).toEqual([["ri", "jp"]]);
  });

  test("returns nothing when the URL carries no preference context", () => {
    expect(preferenceQueryParameters()).toEqual([]);
  });
});

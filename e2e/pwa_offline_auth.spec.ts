import { expect, test } from "playwright/test";

import { authSurfaceUrl } from "../playwright.config";

// End-to-end behaviour of the offline fallback on the auth credential gateway surface.
//
// The worker is Rails' own recipe and carries no path exclusions: every failed navigation on this
// origin gets the offline document. That is safe here because the offline page's retry control is
// `<form action="." method="get">`, which requests the current URL's directory and therefore cannot
// resubmit a consumed authorization code. See adr/pwa-offline-route-exception.md.

const OFFLINE_HEADING = "ネットワークに接続できません";

const origin = () => authSurfaceUrl().replace(/\/$/, "");

const cachedUrls = (page: import("playwright/test").Page) =>
  page.evaluate(async () => {
    const keys = await caches.keys();
    const entries = await Promise.all(
      keys.map(async (key) => {
        const cache = await caches.open(key);
        const requests = await cache.keys();
        return requests.map((request) => request.url);
      }),
    );
    return entries.flat();
  });

test.beforeEach(async ({ page }) => {
  await page.goto(`${origin()}/`);
  await page.evaluate(() => navigator.serviceWorker.ready);
  await expect.poll(() => cachedUrls(page)).toContain(`${origin()}/offline`);
});

test("caches only the offline document on the credential gateway origin", async ({ page }) => {
  const urls = await cachedUrls(page);

  expect(urls).toEqual([`${origin()}/offline`]);
});

test("serves the offline page for an ordinary navigation while offline", async ({
  page,
  context,
}) => {
  await context.setOffline(true);

  await page.goto(`${origin()}/`);

  await expect(page.getByRole("heading", { name: OFFLINE_HEADING })).toBeVisible();
});

test("keeps no credential material in cache storage", async ({ page }) => {
  const urls = await cachedUrls(page);

  expect(urls.some((url) => url.includes("oauth"))).toBe(false);
  expect(urls.some((url) => url.includes("oidc"))).toBe(false);
  expect(urls.some((url) => url.includes(".well-known"))).toBe(false);
});

test("the retry control cannot replay a consumed authorization code", async ({ page, context }) => {
  await context.setOffline(true);
  await page.goto(`${origin()}/social/google/callback?code=consumed&state=abc`);
  await expect(page.getByRole("heading", { name: OFFLINE_HEADING })).toBeVisible();

  // The retry control is the official template's `<form action="." method="get">`.
  const retryForm = page.locator("form").first();
  await expect(retryForm).toHaveAttribute("action", ".");

  const retryTarget = await page.evaluate(() => new URL(".", location.href).toString());

  expect(retryTarget).toBe(`${origin()}/social/google/`);
  expect(retryTarget).not.toContain("code=");
  expect(retryTarget).not.toContain("state=");
});

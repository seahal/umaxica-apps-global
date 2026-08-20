import { expect, test } from "playwright/test";

import { baseSurfaceUrl } from "../playwright.config";

// End-to-end behaviour of the offline fallback on the base service surface.
//
// The worker is the recipe Rails' own PWA generator ships: cache /offline on install, answer failed
// navigations from that cache. These tests measure what that gets us for plain, Turbo, and Inertia
// navigation. See adr/pwa-offline-route-exception.md.

const OFFLINE_HEADING = "ネットワークに接続できません";

const origin = () => baseSurfaceUrl().replace(/\/$/u, "");

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
  // The install handler populates the cache in waitUntil, which can outlive `ready`.
  await expect.poll(() => cachedUrls(page)).toContain(`${origin()}/offline`);
});

test("caches the offline document and nothing else", async ({ page }) => {
  const urls = await cachedUrls(page);

  expect(urls).toEqual([`${origin()}/offline`]);
});

test("serves the offline page for a direct navigation while offline", async ({ page, context }) => {
  await context.setOffline(true);

  await page.goto(`${origin()}/welcome`);

  await expect(page.getByRole("heading", { name: OFFLINE_HEADING })).toBeVisible();
});

test("serves the offline page on reload while offline", async ({ page, context }) => {
  await context.setOffline(true);

  await page.reload();

  await expect(page.getByRole("heading", { name: OFFLINE_HEADING })).toBeVisible();
});

test("serves the offline page when a Turbo link navigation fails", async ({ page, context }) => {
  // Turbo issues a fetch for link clicks. That fetch is not a navigation, so the worker does not
  // answer it; Turbo falls back to a real navigation, which the worker does answer. If Turbo ever
  // stops falling back, this fails and the Turbo handling decision has to be reopened.
  const link = page.locator('a[href^="/"]').first();
  await expect(link).toBeVisible();

  await context.setOffline(true);
  await link.click();

  await expect(page.getByRole("heading", { name: OFFLINE_HEADING })).toBeVisible();
});

// Step 2(c) of the staged verification: measure what an Inertia <Link> click does while offline.
// Inertia navigates with XMLHttpRequest, whose request mode is never "navigate", so the worker is
// expected not to answer it. This test records the actual outcome. Only if it fails do we add
// network error handling through Inertia's own router.on("networkError", …) API.
test("records what an Inertia link navigation does while offline", async ({ page, context }) => {
  await page.goto(`${origin()}/groups`);
  const link = page.locator('a[href^="/groups/"]').first();

  test.skip((await link.count()) === 0, "no Inertia link rendered on /groups in this environment");

  await context.setOffline(true);
  await link.click();

  await expect(page.getByRole("heading", { name: OFFLINE_HEADING })).toBeVisible();
});

test("restores the real page when the retry control is used back online", async ({
  page,
  context,
}) => {
  await context.setOffline(true);
  await page.goto(`${origin()}/`);
  await expect(page.getByRole("heading", { name: OFFLINE_HEADING })).toBeVisible();

  await context.setOffline(false);
  await page.getByRole("button", { name: "再試行" }).click();

  await expect(page.getByRole("heading", { name: OFFLINE_HEADING })).toBeHidden();
});

test("leaves an HTTP 404 as a 404 rather than reporting it as offline", async ({ page }) => {
  // fetch() only rejects on a network failure, so an error status must never reach the fallback.
  const response = await page.goto(`${origin()}/this-path-does-not-exist`);

  expect(response?.status()).toBe(404);
  await expect(page.getByRole("heading", { name: OFFLINE_HEADING })).toBeHidden();
});

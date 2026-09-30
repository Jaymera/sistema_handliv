import { expect, test } from '@playwright/test';

// Demo mode gives a deterministic station set without a backend or credentials.
// Route interception is NOT used to fake /mt5/stats — real data priority is a
// product rule tested in the unit suite, not something E2E should simulate.

test.beforeEach(async ({ page }) => {
  // Static demo build has no authentication backend; never intercept /mt5/stats.
  await page.route('**/api/v1/me/features', route => route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ features: { trading_panel: false, auto_robot: false } }) }));
  await page.goto('/(tabs)/trading-floor');
  await expect(page.getByText('TRADING FLOOR', { exact: true })).toBeVisible();
  await expect(page.getByRole('link', { name: /Floor/ })).toHaveCount(1);
});

test('demo floor renders stations, summary board and detail modal', async ({ page }) => {
  await page.getByRole('button', { name: 'Explorar demo' }).click();
  await expect(page.getByText('DEMO · DADOS SIMULADOS')).toBeVisible();

  const canvas = page.locator('[data-testid="floor-canvas"]');
  await expect(canvas).toBeVisible();
  // 20 default robots + sector signage on the scene.
  await expect(page.getByText('20 estações', { exact: false })).toBeVisible();

  // Board shows real summary fields (US$ demo currency, signed daily result).
  await expect(page.getByText('Lucro diário')).toBeVisible();

  // Open a station detail from the accessible quick list (canvas hit-test covered by unit tests).
  await page.getByRole('button', { name: /Detalhes de LIVWELL/ }).first().click();
  await expect(page.getByText('Magic', { exact: true })).toBeVisible();
  await expect(page.getByText('Somente leitura. Nenhuma ordem pode ser enviada por esta tela.', { exact: true })).toBeVisible();
  await page.keyboard.press('Escape');
  await expect(page.getByText('Somente leitura. Nenhuma ordem pode ser enviada por esta tela.', { exact: true })).toHaveCount(0);
});

test('zoom controls and fit screen respond', async ({ page }) => {
  await page.getByRole('button', { name: 'Explorar demo' }).click();
  await page.getByRole('button', { name: '+' }).click();
  await page.getByRole('button', { name: '−' }).click();
  await page.getByRole('button', { name: 'Fit Screen' }).click();
  await expect(canvas(page)).toBeVisible();
});

test('mobile exposes the scene above the metrics', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name !== 'mobile-chromium');
  await page.getByRole('button', { name: 'Explorar demo' }).click();
  await expect(canvas(page)).toBeInViewport({ ratio: 0.1 });
  await expect(page.getByRole('button', { name: '150 robôs' })).toBeInViewport({ ratio: 1 });
});

test('no console errors on the floor', async ({ page }) => {
  const errors: string[] = [];
  page.on('pageerror', (error) => errors.push(String(error)));
  page.on('console', (message) => { if (message.type() === 'error') errors.push(message.text()); });
  await page.getByRole('button', { name: 'Explorar demo' }).click();
  await page.waitForTimeout(2500);
  expect(errors).toEqual([]);
});

function canvas(page: import('@playwright/test').Page) {
  return page.locator('[data-testid="floor-canvas"]');
}

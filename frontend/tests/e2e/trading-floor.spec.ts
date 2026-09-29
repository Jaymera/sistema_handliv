import { expect, test } from '@playwright/test';

// Demo mode gives a deterministic station set without a backend or credentials.
// Route interception is NOT used to fake /mt5/stats — real data priority is a
// product rule tested in the unit suite, not something E2E should simulate.

test.beforeEach(async ({ page }) => {
  await page.goto('/(tabs)/trading-floor');
  await expect(page.getByText('TRADING FLOOR', { exact: true })).toBeVisible();
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
  await expect(page.getByText('Magic')).toBeVisible();
  await expect(page.getByText('Somente leitura', { exact: false })).toBeVisible();
  await page.keyboard.press('Escape');
  await expect(page.getByText('Somente leitura', { exact: false })).toHaveCount(0);
});

test('zoom controls and fit screen respond', async ({ page }) => {
  await page.getByRole('button', { name: 'Explorar demo' }).click();
  await page.getByRole('button', { name: '+' }).click();
  await page.getByRole('button', { name: '−' }).click();
  await page.getByRole('button', { name: 'Fit Screen' }).click();
  await expect(canvas(page)).toBeVisible();
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

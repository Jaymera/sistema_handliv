import { expect, test } from '@playwright/test';

// Strictly isolated browser fixtures. No user credentials or invented quotes
// enter the app, production API, or stored account data.
const catalogue = [
  { symbol: 'PETR4', name: 'Petrobras — fixture de interface', market: 'B3', asset_type: 'stock', currency: 'BRL' },
  { symbol: 'AAPL', name: 'Apple — fixture de interface', market: 'US', asset_type: 'stock', currency: 'USD' },
  { symbol: 'BTCUSD', name: 'Bitcoin — fixture de interface', market: 'CRYPTO', asset_type: 'crypto', currency: 'USD' },
  { symbol: 'EURUSD', name: 'Euro / dólar — fixture de interface', market: 'FOREX', asset_type: 'forex', currency: 'USD' },
];

test('dashboard workspace renders real-contract catalogue and watchlist without overflow', async ({ page, isMobile }) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.addInitScript(() => {
    localStorage.setItem('auth.access', 'isolated-ui-fixture-not-a-real-credential');
    localStorage.setItem('auth.user', JSON.stringify({ id: 'ui-test-only', name: 'Verificação visual', email: 'qa@example.invalid', role: 'user', locale: 'pt-BR', theme: 'dark', force_password_change: false }));
    localStorage.setItem('auth.lastActivity', String(Date.now()));
  });
  await page.route('**/api/v1/**', async route => {
    const pathname = new URL(route.request().url()).pathname.replace('/api/v1', '');
    let json: unknown;
    if (pathname === '/assets') {
      const q = new URL(route.request().url()).searchParams.get('q')?.toUpperCase();
      const items = q ? catalogue.filter(asset => `${asset.symbol} ${asset.name}`.toUpperCase().includes(q)) : catalogue;
      json = { items, total: items.length, page: 1, limit: 100 };
    }
    else if (pathname === '/watchlist') json = [{ asset: catalogue[0], sort_order: 0 }];
    else if (pathname === '/watchlist/suggested') json = [catalogue[1]];
    else if (pathname === '/me/features') json = { plan_code: 'free', plan_status: 'active', payment_ok: true, features: { trading_panel: false, auto_robot: false, assets_analyzed_limit: 10, assets_analyzed_used: 0 }, links: {} };
    else json = [];
    await route.fulfill({ json });
  });
  await page.goto('/');
  await expect(page.getByTestId('dashboard-workspace')).toBeVisible();
  await expect(page.getByText('PETR4', { exact: true }).first()).toBeVisible();
  const dimensions = await page.evaluate(() => ({ scroll: document.documentElement.scrollWidth, viewport: window.innerWidth }));
  expect(dimensions.scroll).toBeLessThanOrEqual(dimensions.viewport + 2);
  expect(errors).toEqual([]);
  if (process.env.HANDLIV_CAPTURE_UI === '1') {
    const path = require('node:path');
    await page.screenshot({ path: path.join(process.env.LOCALAPPDATA!, 'Temp', `handliv-dashboard-workspace-${isMobile ? 'mobile' : 'desktop'}.png`), fullPage: true });
  }
  // Enter during the debounce interval must not select the previous ticker.
  const search = page.getByLabel('Buscar ativo por símbolo ou nome');
  const settled = page.waitForResponse(response => new URL(response.url()).searchParams.get('q') === 'PETR');
  await search.fill('PETR');
  await settled;
  await expect(page.getByRole('button', { name: 'Analisar PETR4', exact: true })).toHaveCount(2);
  await search.fill('AAPL');
  await search.press('Enter');
  await page.waitForTimeout(100);
  await expect(page).toHaveURL(/localhost:8081\/$/);
  expect(errors).toEqual([]);
});

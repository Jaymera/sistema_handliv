import { expect, test } from '@playwright/test';

// Local contract regression only: synthetic auth/telemetry never touches a real API.
// This is not proof of the user's live EA heartbeat or production account data.
test('fresh avatars survive browser clock 152 seconds behind server', async ({ page, baseURL }) => {
  expect(new URL(baseURL!).hostname).toBe('localhost');
  let statsRequests = 0;
  await page.addInitScript(() => {
    Object.defineProperty(document, 'hasFocus', { configurable: true, value: () => false });
    localStorage.setItem('auth.access', 'local-test-not-a-real-token');
    localStorage.setItem('auth.refresh', 'local-test-not-a-real-refresh');
    localStorage.setItem('auth.lastActivity', String(Date.now()));
    localStorage.setItem('auth.user', JSON.stringify({
      id: 'fixture-user', name: 'Contract fixture', email: 'fixture@example.invalid',
      role: 'user', locale: 'pt-BR', theme: 'dark', force_password_change: false,
    }));
  });
  // Abort every unmatched API call, including refresh, so fixtures cannot leak to production.
  await page.route('**/api/v1/**', async route => {
    const path = new URL(route.request().url()).pathname;
    if (path === '/api/v1/me/features') {
      await route.fulfill({ json: { features: { trading_panel: true, auto_robot: false } } });
    } else if (path === '/api/v1/mt5/stats') {
      statsRequests++;
      const updated_at = new Date(Date.now() + 152_000).toISOString();
      await route.fulfill({ headers: { Date: new Date(Date.now() + 152_000).toUTCString() }, json: { items: [{
        id: 'fixture-account', account_number: '000', broker: 'TEST ONLY', is_active: true,
        stats: { currency: 'USD', balance: 1000, equity: 1000, profit_day: 0, floating_pl: 0,
          dd_percent: 0, open_positions: 0, updated_at },
        robots: [{ magic: '101', symbol: 'EURUSD', heartbeat: true, is_present: true,
          open_positions: 0, floating_pl: 0, profit_total: 0, total_trades: 0,
          win_trades: 0, loss_trades: 0, updated_at }],
      }] } });
    } else await route.abort();
  });
  await page.goto('/trading-floor');
  await expect(page.getByText('TRADING FLOOR', { exact: true })).toBeVisible();
  await expect.poll(() => statsRequests, { timeout: 5000 }).toBe(1);
  await expect(page.locator('[data-testid="floor-canvas"]')).toHaveAttribute(
    'data-agent-targets', /fixture-account:magic:101/,
  );
  await expect(page.getByText('Atualização pausada', { exact: true })).toBeVisible();

});

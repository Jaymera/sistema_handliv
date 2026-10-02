import { expect, test } from '@playwright/test';

test('old Painel routes redirect to Perfil and hero line break renders', async ({ page, baseURL }) => {
  expect(new URL(baseURL!).hostname).toBe('localhost');
  await page.addInitScript(() => {
    localStorage.setItem('auth.access', 'isolated-ui-fixture-not-a-real-credential');
    localStorage.setItem('auth.user', JSON.stringify({ id: 'ui-test-only', name: 'Verificação visual', email: 'qa@example.invalid', role: 'user', locale: 'pt-BR', theme: 'dark', force_password_change: false }));
    localStorage.setItem('auth.lastActivity', String(Date.now()));
  });
  await page.route('**/api/v1/**', async route => {
    const pathname = new URL(route.request().url()).pathname.replace('/api/v1', '');
    let json: unknown;
    if (pathname === '/assets') json = { items: [], total: 0, page: 1, limit: 100 };
    else if (pathname === '/watchlist') json = [];
    else if (pathname === '/watchlist/suggested') json = [];
    else if (pathname === '/me/features') json = { plan_code: 'free', plan_status: 'active', payment_ok: true, features: { trading_panel: false, auto_robot: false, assets_analyzed_limit: 10, assets_analyzed_used: 0 }, links: {} };
    else json = [];
    await route.fulfill({ json });
  });

  // Rotas antigas da aba Painel caem no Perfil
  await page.goto('/(tabs)/trading');
  await page.waitForURL(/profile/, { timeout: 15000 });
  await page.goto('/trading-panel');
  await page.waitForURL(/profile/, { timeout: 15000 });

  // Hero do Início: quebra de linha REAL entre "próxima" e "oportunidade."
  await page.goto('/');
  await page.waitForTimeout(3000);
  const heroText = await page.evaluate(() => {
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    while (walker.nextNode()) {
      const t = walker.currentNode.textContent ?? '';
      if (t.includes('Encontre sua próxima')) return t;
    }
    return '';
  });
  expect(heroText).toBe('Encontre sua próxima\noportunidade.');
});
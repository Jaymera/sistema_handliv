import { expect, test } from '@playwright/test';

async function fixture(page: import('@playwright/test').Page, baseURL: string, ultimate = true) {
  expect(new URL(baseURL).hostname).toBe('localhost');
  const writes: any[] = [];
  const unexpected: string[] = [];
  await page.addInitScript(() => {
    localStorage.setItem('auth.access', 'isolated-fixture');
    localStorage.setItem('auth.refresh', 'isolated-fixture-refresh');
    localStorage.setItem('auth.lastActivity', String(Date.now()));
    localStorage.setItem('auth.user', JSON.stringify({ id: 'fixture', name: 'Fixture', email: 'fixture@example.invalid', role: 'user', locale: 'pt-BR', theme: 'dark' }));
  });
  const rules: Record<string, any[]> = { a: [], b: [] };
  let failB = false;
  let holdWrite: (() => void) | null = null;
  let delayWrite = false;
  await page.route('**/*', async route => {
    const req = route.request();
    const url = new URL(req.url());
    if (!['localhost', '127.0.0.1'].includes(url.hostname)) { unexpected.push(req.url()); return route.abort(); }
    if (!url.pathname.startsWith('/api/v1/')) return route.continue();
    if (url.pathname === '/api/v1/me/features') return route.fulfill({ json: { features: { trading_panel: true, auto_robot: ultimate, mt5_accounts_max: 2 } } });
    if (url.pathname === '/api/v1/mt5/stats') return route.fulfill({ json: { items: ['a', 'b'].map(id => ({ id, account_number: id === 'a' ? '001-fixture' : '002-fixture', broker: 'TEST ONLY', is_active: true, stats: null })) } });
    if (url.pathname === '/api/v1/mt5/orders' && req.method() === 'GET') return route.fulfill({ json: { items: [] } });
    if (url.pathname === '/api/v1/watchlist') return route.fulfill({ json: [{ asset: { symbol: 'EURUSD', name: 'Euro' }, sort_order: 0 }] });
    if (url.pathname === '/api/v1/mt5/automation') {
      const id = url.searchParams.get('account_id')!;
      if (id === 'b' && failB) return route.fulfill({ status: 403, json: { error: { message: 'Conta indisponível' } } });
      return route.fulfill({ json: { items: rules[id] } });
    }
    if (url.pathname === '/api/v1/mt5/automation/EURUSD' && req.method() === 'PUT') {
      const body = req.postDataJSON(); writes.push(body);
      if (delayWrite) await new Promise<void>(resolve => { holdWrite = resolve; });
      const rule = { id: 'fixture-rule', symbol: 'EURUSD', last_signal: 'COMPRA FORTE', last_status: 'pending', ...body };
      rules[body.account_id] = [rule];
      return route.fulfill({ json: rule });
    }
    unexpected.push(req.method() + ' ' + url.pathname); return route.abort();
  });
  await page.goto('/mt5');
  return { writes, unexpected, failB: () => { failB = true; }, delay: () => { delayWrite = true; }, release: () => holdWrite?.() };
}

test('favorites automation is explicit, validates lots and confirms real-order risk without submitting orders', async ({ page, baseURL }) => {
  const f = await fixture(page, baseURL!);
  const card = page.getByTestId('automation-EURUSD');
  await expect(card).toBeVisible();
  await expect(card.getByLabel('Símbolo exato na corretora')).toHaveValue('');
  await expect(card.getByLabel('Volume em lotes')).toHaveValue('');
  await card.getByLabel('Símbolo exato na corretora').fill('EURUSD.a');
  await card.getByLabel('Volume em lotes').fill('0.001');
  await expect(card.getByRole('button', { name: 'Salvar desativada', exact: true })).toBeDisabled();
  await card.getByLabel('Volume em lotes').fill('0.10');
  await card.getByRole('button', { name: 'Compra e venda', exact: true }).click();
  await expect(card.getByLabel('Stop ATR multiplicador')).toHaveValue('2.00');
  await expect(card.getByLabel('Alvo ATR multiplicador')).toHaveValue('3.00');
  await card.getByLabel('Stop ATR multiplicador').fill('0.09');
  await expect(card.getByRole('button', { name: 'Ativar…', exact: true })).toBeDisabled();
  await expect(card.getByRole('button', { name: 'Salvar desativada', exact: true })).toBeDisabled();
  await card.getByLabel('Stop ATR multiplicador').fill('2.00');
  await card.getByLabel('Alvo ATR multiplicador').fill('20.01');
  await expect(card.getByRole('button', { name: 'Ativar…', exact: true })).toBeDisabled();
  await card.getByLabel('Alvo ATR multiplicador').fill('3.00');
  expect(f.writes).toEqual([]);
  await card.getByRole('button', { name: 'Salvar desativada', exact: true }).click();
  await expect.poll(() => f.writes.length).toBe(1);
  expect(f.writes[0]).toEqual({ account_id: 'a', broker_symbol: 'EURUSD.a', direction: 'both', volume: '0.10', enabled: false, sl_atr_multiplier: '2.00', tp_atr_multiplier: '3.00' });
  await card.getByRole('button', { name: 'Ativar…', exact: true }).click();
  const confirm = card.getByTestId('automation-confirm');
  await expect(confirm).toContainText('001-fixture');
  await expect(confirm).toContainText('EURUSD.a');
  await expect(confirm).toContainText('0.10');
  await expect(confirm).toContainText('Compra e venda');
  await expect(confirm).toContainText('ordens reais');
  await expect(confirm).toContainText('Stop 2.00× ATR');
  await expect(confirm).toContainText('Alvo 3.00× ATR');
  await expect(confirm).toContainText('ATR14 H1');
  expect(f.writes).toHaveLength(1);
  await confirm.getByRole('button', { name: 'Cancelar', exact: true }).click();
  expect(f.writes).toHaveLength(1);
  await card.getByRole('button', { name: 'Ativar…', exact: true }).click();
  await card.getByRole('button', { name: 'Confirmar ativação', exact: true }).click();
  await expect.poll(() => f.writes.length).toBe(2);
  expect(f.writes[1].enabled).toBe(true);
  await expect(card).toContainText('COMPRA FORTE');
  await expect(card).toContainText('pending');
  await expect(card).toContainText('não confirma execução');
  await card.getByRole('button', { name: 'Desativar', exact: true }).click();
  await expect.poll(() => f.writes.length).toBe(3);
  expect(f.writes[2].enabled).toBe(false);
  expect(f.unexpected).toEqual([]);
});

test('saving freezes controls and account switches never reuse another account draft or late response', async ({ page, baseURL }) => {
  const f = await fixture(page, baseURL!);
  const card = page.getByTestId('automation-EURUSD');
  await expect(card).toBeVisible();
  await card.getByLabel('Símbolo exato na corretora').fill('EURUSD.a');
  await card.getByLabel('Volume em lotes').fill('0.20');
  f.delay();
  await card.getByRole('button', { name: 'Salvar desativada', exact: true }).click();
  await expect.poll(() => f.writes.length).toBe(1);
  await expect(card.getByLabel('Símbolo exato na corretora')).not.toBeEditable();
  await expect(card.getByLabel('Stop ATR multiplicador')).not.toBeEditable();
  await expect(card.getByRole('button', { name: 'Compra', exact: true })).toBeDisabled();
  await page.getByText('002-fixture', { exact: true }).click();
  await expect(card.getByLabel('Símbolo exato na corretora')).toHaveValue('');
  f.release();
  await expect(card.getByLabel('Volume em lotes')).toHaveValue('');
  expect(f.writes).toHaveLength(1);
  await page.getByText('001-fixture', { exact: true }).click();
  await expect(card.getByLabel('Símbolo exato na corretora')).toHaveValue('EURUSD.a');
  f.failB();
  await page.getByText('002-fixture', { exact: true }).click();
  await expect(page.getByText('Não foi possível carregar favoritos/configuração desta conta. Controles bloqueados.')).toBeVisible();
  await expect(card).toHaveCount(0);
  expect(f.writes).toHaveLength(1);
  expect(f.unexpected).toEqual([]);
});

test('Start displays Ultimate upsell without fetching automation', async ({ page, baseURL }) => {
  const f = await fixture(page, baseURL!, false);
  await expect(page.getByText(/Disponível no Ultimate/)).toBeVisible();
  await expect(page.getByTestId('automation-EURUSD')).toHaveCount(0);
  expect(f.writes).toEqual([]);
  expect(f.unexpected).toEqual([]);
});

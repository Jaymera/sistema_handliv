import { expect, test } from '@playwright/test';

// Isolated local fixtures only. No real account, orders, or authentication.
test('present robots with open positions walk, take breaks and remain selectable', async ({ page, baseURL }, testInfo) => {
  expect(new URL(baseURL!).hostname).toBe('localhost');
  const origin = Date.now();
  await page.clock.setFixedTime(origin);
  await page.addInitScript(() => {
    Object.defineProperty(document, 'hasFocus', { configurable: true, value: () => false });
    localStorage.setItem('auth.access', 'local-fixture-not-a-token');
    localStorage.setItem('auth.refresh', 'local-fixture-not-a-refresh');
    localStorage.setItem('auth.lastActivity', String(Date.now()));
    localStorage.setItem('auth.user', JSON.stringify({id:'fixture', name:'Local fixture', email:'fixture@example.invalid',role:'user',locale:'pt-BR',theme:'dark',force_password_change:false}));
  });
  await page.route('**/api/v1/**', async route => {
    const path = new URL(route.request().url()).pathname;
    if (path.endsWith('/me/features')) return route.fulfill({json:{features:{trading_panel:true, auto_robot:false}}});
    if (!path.endsWith('/mt5/stats')) return route.abort();
    const updated_at = new Date(origin).toISOString();
    return route.fulfill({headers:{Date:new Date(origin).toUTCString()},json:{items:[{
      id:'routine-fixture',account_number:'TEST ONLY',broker:'LOCAL FIXTURE',is_active:true,
      stats:{currency:'USD',balance:1000,equity:1000,profit_day:0,floating_pl:0,dd_percent:0,open_positions:12,updated_at},
      robots:Array.from({length:12},(_,i)=>({magic:String(101+i),symbol:'EURUSD',heartbeat:true,is_present:true,open_positions:1,floating_pl:0,profit_total:0,total_trades:0,win_trades:0,loss_trades:0,updated_at})),
    }]}});
  });
  await page.goto('/trading-floor');
  const floor=page.locator('[data-testid="floor-canvas"]');
  await expect(floor).toHaveAttribute('data-agent-targets', /routine-fixture/);
  await floor.scrollIntoViewIfNeeded();
  type Target={id:string;x:number;y:number;walking:boolean;activity:string};
  const targets=()=>floor.evaluate(el=>JSON.parse((el as HTMLCanvasElement).dataset.agentTargets!) as Target[]);
  const activities=new Set<string>();
  let moved=false, selected=false;
  let before=await targets();
  for(let step=0;step<24;step++){
    await page.clock.setFixedTime(origin+step*30_000);
    await page.waitForTimeout(600);
    const current=await targets();
    for(const p of current)activities.add(p.activity);
    if(current.some(p=>p.walking&&before.some(q=>q.id===p.id&&Math.hypot(q.x-p.x,q.y-p.y)>2)))moved=true;
    const box=(await floor.boundingBox())!;
    const walker=current.find(p=>p.walking&&p.x>20&&p.x<box.width-20&&p.y>20&&p.y<box.height-20);
    if(walker&&!selected){
      await page.screenshot({path:testInfo.outputPath('natural-office-walking.png')});
      await page.mouse.click(box.x+walker.x,box.y+walker.y);
      await expect(page.getByText('Somente leitura. Nenhuma ordem pode ser enviada por esta tela.',{exact:true})).toBeVisible();
      await expect(page.getByText(walker.id.split(':').pop()!, {exact:true})).toBeVisible();
      await page.keyboard.press('Escape');
      selected=true;
    }
    before=current;
    if(moved&&selected&&Array.from(activities).some(a=>!['desk','walking'].includes(a)))break;
  }
  expect(moved,'robots with open positions must have a visible walking routine').toBeTruthy();
  expect(selected,'moving person must remain selectable').toBeTruthy();
  expect(Array.from(activities).some(a=>!['desk','walking'].includes(a)),'person must pause for an office activity').toBeTruthy();
});

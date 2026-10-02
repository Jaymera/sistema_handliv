import {test,expect} from '@playwright/test';

test('explicit floor animation preference overrides reduced motion, persists and can pause again',async({page,baseURL})=>{
 expect(new URL(baseURL!).hostname).toBe('localhost');
 await page.emulateMedia({reducedMotion:'reduce'});
 await page.route('**/api/v1/me/features',r=>r.fulfill({json:{features:{trading_panel:false,auto_robot:false}}}));
 await page.goto('/trading-floor');
 await page.getByRole('button',{name:'Explorar demo'}).click();
 const c=page.locator('[data-testid="floor-canvas"]');
 const poses=()=>c.evaluate(el=>JSON.parse((el as HTMLCanvasElement).dataset.agentTargets!));
 await expect(c).toHaveAttribute('data-agent-targets',/desk/);
 expect((await poses()).every((p:any)=>!p.walking)).toBe(true);
 await page.getByRole('button',{name:'Ativar animações',exact:true}).click();
 await expect(page.getByRole('button',{name:'Pausar animações',exact:true})).toBeVisible();
 await expect.poll(async()=> (await poses()).some((p:any)=>p.walking)).toBe(true);
 await page.reload();
 await page.getByRole('button',{name:'Explorar demo'}).click();
 await expect(page.getByRole('button',{name:'Pausar animações',exact:true})).toBeVisible();
 await page.getByRole('button',{name:'Pausar animações',exact:true}).click();
 await expect.poll(async()=> (await poses()).every((p:any)=>!p.walking)).toBe(true);
 await page.reload();
 await page.getByRole('button',{name:'Explorar demo'}).click();
 await expect(page.getByRole('button',{name:'Ativar animações',exact:true})).toBeVisible();
});

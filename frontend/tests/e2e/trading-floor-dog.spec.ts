import {test,expect} from '@playwright/test';

test('dog body actually moves on canvas without online robots and reduced motion freezes it',async({page,baseURL})=>{
 expect(new URL(baseURL!).hostname).toBe('localhost');
 await page.route('**/api/v1/**',route=>route.request().url().endsWith('/me/features')?route.fulfill({json:{features:{trading_panel:false,auto_robot:false}}}):route.abort());
 const start=Math.floor(Date.now()/30000)*30000;
 await page.clock.setFixedTime(start+2000);
 await page.goto('/trading-floor');
 const canvas=page.locator('[data-testid="floor-canvas"]');
 await expect(canvas).toBeVisible();
 await canvas.scrollIntoViewIfNeeded();
 const body=()=>canvas.evaluate(el=>{
  const c=el as HTMLCanvasElement,ctx=c.getContext('2d')!,p=ctx.getImageData(0,0,c.width,c.height).data;
  let x=0,y=0,n=0;
  for(let i=0;i<p.length;i+=4)if(p[i]===168&&p[i+1]===120&&p[i+2]===82){const k=i/4;x+=k%c.width;y+=Math.floor(k/c.width);n++;}
  return {x:x/n,y:y/n,n};
 });
 await page.waitForTimeout(600);
 const first=await body();expect(first.n).toBeGreaterThan(0);
 await page.clock.setFixedTime(start+8000);await page.waitForTimeout(600);
 const second=await body();expect(second.n).toBeGreaterThan(0);
 expect(Math.hypot(second.x-first.x,second.y-first.y),'dog-colored pixels must change position').toBeGreaterThan(3);
 await page.emulateMedia({reducedMotion:'reduce'});await page.waitForTimeout(600);
 const still=await body();await page.clock.setFixedTime(start+16000);await page.waitForTimeout(600);
 const later=await body();expect(later).toEqual(still);
});

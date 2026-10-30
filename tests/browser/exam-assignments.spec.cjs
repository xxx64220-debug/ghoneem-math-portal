const {test,expect}=require('@playwright/test');
const {setup}=require('./assignment-fixture.cjs');
const first='[data-ex-assign="fixture-exam-1"]';
const group=id=>`[data-assignment-group="${id}"]`;
const student=id=>`[data-assignment-student="student-${id}"]`;
async function clean(a){expect(a.errors).toEqual([]);expect(a.unexpected).toEqual([]);}
async function fits(page){
 const layout=await page.locator('#editor').evaluate(e=>({width:e.clientWidth,scroll:e.scrollWidth,box:e.getBoundingClientRect().toJSON(),height:innerHeight,viewport:innerWidth}));
 expect(layout.scroll).toBeLessThanOrEqual(layout.width+1);
 expect(layout.box.x).toBeGreaterThanOrEqual(0);expect(layout.box.right).toBeLessThanOrEqual(layout.viewport+1);
 expect(layout.box.y).toBeGreaterThanOrEqual(0);expect(layout.box.bottom).toBeLessThanOrEqual(layout.height+1);
}
test('mixed recipients, overlap, search, paged roster, long names and scrolling',async({page,context},info)=>{
 const a=await setup(page,context);await page.locator(first).click();
 await expect(page.locator('[data-assignment-student]')).toHaveCount(1105);
 expect(a.reads.some(r=>r.table==='roster'&&r.range[0]===1000)).toBe(true);
 await expect(page.locator(group('other-track'))).toHaveCount(0);
 await page.locator(group('group-a')).check();await page.locator(group('group-b')).check();
 await page.locator(student(1)).check();
 await expect(page.locator('[data-assignment-review]')).toContainText('4 unique students currently eligible · 2 reached by more than one selection');
 await expect(page.locator('.assignment-recipient-list li')).toHaveCount(4);
 const search=page.locator('[data-assignment-search]');await search.fill('STUDENT1000@EXAMPLE.TEST');
 await expect(page.locator('[data-assignment-person]:visible')).toHaveCount(1);
 await page.getByRole('button',{name:'Select shown students',exact:true}).click();
 await search.fill('no-match');await expect(page.locator('[data-assignment-empty]')).toBeVisible();
 await search.fill('');await expect(page.locator(student(1))).toBeChecked();await expect(page.locator(student(1000))).toBeChecked();
 await page.locator(student(1104)).scrollIntoViewIfNeeded();await page.locator(student(1104)).check();
 expect(await page.locator('.assignment-student-list').evaluate(e=>e.scrollTop)).toBeGreaterThan(0);
 await fits(page);await page.screenshot({path:info.outputPath('long-student-list.png')});
 await page.getByRole('button',{name:'Select shown students',exact:true}).click();
 await expect(page.locator('.assignment-recipient-list li')).toHaveCount(1105);
 await page.locator('.assignment-recipient-list li').last().scrollIntoViewIfNeeded();
 expect(await page.locator('.assignment-recipient-list').evaluate(e=>e.scrollTop)).toBeGreaterThan(0);
 await page.locator('#aopen').fill('2026-11-01T10:00');await page.locator('#aclose').fill('2026-11-02T10:00');
 await page.locator('#editSave').scrollIntoViewIfNeeded();await fits(page);
 await page.screenshot({path:info.outputPath('assignment-dates-actions.png')});
 await page.getByRole('button',{name:'Cancel',exact:true}).click();expect(a.calls).toEqual([]);await clean(a);
});
test('empty recipients and reversed dates stay open; valid dates and existing records are preserved',async({page,context})=>{
 const existing={id:'existing',exam_id:'fixture-exam-1',group_id:'group-a',user_id:null,open_at:'2025-01-01T00:00:00Z',close_at:'2025-01-02T00:00:00Z'};
 const a=await setup(page,context,{existing:[existing]});await page.locator(first).click();
 await page.locator('#editSave').click();await expect(page.locator('#editError')).toContainText('Select at least');
 await page.locator(group('group-a')).check();await page.locator(group('group-b')).check();await page.locator(student(4)).check();
 await page.locator('#aopen').fill('2026-11-02T10:00');await page.locator('#aclose').fill('2026-11-01T10:00');
 await page.locator('#editSave').click();await expect(page.locator('#editError')).toContainText('Closing time must be after');expect(a.calls).toEqual([]);
 await page.locator('#aopen').fill('2026-11-01T09:00');await page.locator('#editSave').click();await expect(page.locator('#editor')).not.toBeVisible();
 expect(a.calls).toHaveLength(2);expect(a.fixtures.assignments[0]).toEqual(existing);
 expect(a.calls.every(c=>c.data.open_at==='2026-11-01T07:00:00.000Z'&&c.data.close_at==='2026-11-01T08:00:00.000Z')).toBe(true);await clean(a);
});
test('pending save blocks repeated clicks, Escape and changing recipients; partial retry saves only the failure',async({page,context},info)=>{
 let reject=true;const a=await setup(page,context,{fail:body=>body.data.user_id==='student-4'&&reject?'reject':null});
 await page.locator(first).click();await page.locator(group('group-a')).check();await page.locator(student(4)).check();
 let release;a.gate=new Promise(r=>release=r);await page.locator('#editSave').click();
 await expect.poll(()=>a.calls.length).toBe(1);
 await expect(page.locator('#editForm')).toHaveAttribute('aria-busy','true');
 for(const id of ['aopen','aclose','editSave','editCancel'])await expect(page.locator('#'+id)).toBeDisabled();
 await expect(page.locator(student(4))).toBeDisabled();await page.keyboard.press('Escape');await expect(page.locator('#editor')).toBeVisible();
 await page.keyboard.press('Enter');expect(a.calls).toHaveLength(1);
 release();a.gate=null;await expect(page.locator('#editError')).toContainText('Retry to finish');
 await expect(page.locator('#editSave')).toBeEnabled();await expect(page.locator(student(4))).toBeChecked();
 await fits(page);await page.screenshot({path:info.outputPath('partial-failure.png')});
 reject=false;await page.locator('#editSave').click();await expect(page.locator('#editor')).not.toBeVisible();
 expect(a.calls).toHaveLength(3);expect(a.calls.filter(c=>c.data.group_id==='group-a')).toHaveLength(1);expect(a.fixtures.assignments).toHaveLength(2);await clean(a);
});
test('lost response is reconciled without another write',async({page,context})=>{
 const a=await setup(page,context,{fail:()=> 'lost'});await page.locator(first).click();await page.locator(student(4)).check();await page.locator('#editSave').click();
 await expect(page.locator('#editor')).not.toBeVisible();expect(a.calls).toHaveLength(1);expect(a.fixtures.assignments).toHaveLength(1);await clean(a);
});
test('lost response plus failed readback safely retries through a uniqueness conflict',async({page,context})=>{
 const a=await setup(page,context,{fail:()=> 'lost'});await page.locator(first).click();await page.locator(student(4)).check();a.readFailure=true;
 await page.locator('#editSave').click();await expect(page.locator('#editError')).toContainText('Retry to finish');
 a.readFailure=false;a.fail=null;await page.locator('#editSave').click();await expect(page.locator('#editor')).not.toBeVisible();
 expect(a.calls).toHaveLength(2);expect(a.fixtures.assignments).toHaveLength(1);await clean(a);
});
test('group entry preselects only its group and instructor search stays in scope',async({page,context})=>{
 const a=await setup(page,context,{role:'instructor'});
 await page.evaluate(async()=>{const groups=await getRows('groups');await GroupManager.assign(groups[0]);});
 await expect(page.locator(group('group-a'))).toBeChecked();await expect(page.locator(group('group-b'))).not.toBeChecked();
 await expect(page.locator(group('other-teacher'))).toHaveCount(0);await expect(page.locator('[data-assignment-student]')).toHaveCount(4);
 await page.getByRole('button',{name:'Clear groups',exact:true}).click();await page.locator(student(3)).check();
 await page.locator('#groupAssignExam').selectOption('fixture-exam-2');await page.locator('#editSave').click();await expect(page.locator('#editor')).not.toBeVisible();
 expect(a.calls.map(c=>c.data)).toEqual([{exam_id:'fixture-exam-2',group_id:null,user_id:'student-3',open_at:null,close_at:null}]);await clean(a);
});
test('bulk exam retry retains successful targets and completed exams',async({page,context})=>{
 let reject=true;const a=await setup(page,context,{fail:body=>reject&&body.data.exam_id==='fixture-exam-2'&&body.data.user_id==='student-4'?'reject':null});
 await page.locator('[data-bulk-all]').check();await page.locator('[data-bulk-action]').selectOption('assign');await page.locator('[data-bulk-apply]').click();
 await page.locator(group('group-a')).check();await page.locator(student(4)).check();await page.locator('#bulkSave').click();
 await expect(page.locator('#bulkSave')).toHaveText('Retry 1 failed items');expect(a.calls).toHaveLength(4);await fits(page);
 reject=false;await page.locator('#bulkSave').click();await expect(page.locator('#bulkSave')).toHaveText('Done');await expect(page.locator('#bulkSave')).toBeDisabled();
 expect(a.calls).toHaveLength(5);expect(a.fixtures.assignments).toHaveLength(4);expect(a.calls.filter(c=>c.data.exam_id==='fixture-exam-1')).toHaveLength(2);await clean(a);
});

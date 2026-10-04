// Navigation-only enhancement: use the rendered destinations so extensions,
// track restrictions and instructor permissions stay authoritative.
(function(){
  function studentNavigation(){
    const tabs=document.querySelector('.student-tabs');
    if(!tabs||document.getElementById('studentSection'))return;
    const destinations=[...tabs.querySelectorAll('[data-view]')];
    const groups=[['Study',['daily','revision','finalsDiagnosis','mistakes','drill']],['Assessments',['lesson_exam','quiz','full_exam']],['Progress',['overview','history','focus']]];
    const toolbar=document.createElement('div');toolbar.className='portal-navigation';
    const label=document.createElement('label');label.htmlFor='studentSection';label.textContent='Go to section';
    const select=document.createElement('select');select.id='studentSection';
    const added=new Set();
    groups.forEach(([name,ids])=>{
      const group=document.createElement('optgroup');group.label=name;
      ids.forEach(id=>{const button=destinations.find(b=>b.dataset.view===id);if(!button)return;
        const option=document.createElement('option');option.value=id;option.textContent=button.childNodes[0]?.textContent.trim()||button.textContent.trim();group.append(option);added.add(id);
      });if(group.children.length)select.append(group);
    });
    destinations.filter(b=>!added.has(b.dataset.view)).forEach(b=>{const option=document.createElement('option');option.value=b.dataset.view;option.textContent=b.textContent.trim();select.append(option);});
    select.value=DASH.view;
    select.onchange=()=>setDashboardView(select.value);
    const home=document.createElement('button');home.type='button';home.className='btn-ghost';home.textContent='My progress';home.onclick=()=>setDashboardView('overview');
    toolbar.append(label,select,home);tabs.before(toolbar);
    const current=document.createElement('p');current.className='navigation-location';current.id='navigationLocation';
    current.textContent=(ST.track?.name||document.getElementById('listTitle')?.textContent||'My track')+' / '+(select.selectedOptions[0]?.textContent||'Dashboard');
    toolbar.after(current);
  }
  if(typeof paintDashboard==='function'){
    const paint=paintDashboard;
    paintDashboard=function(){const result=paint.apply(this,arguments);studentNavigation();return result;};
    const navigate=setDashboardView;
    setDashboardView=function(view){const result=navigate.apply(this,arguments);window.scrollTo({top:0,behavior:'auto'});return result;};
    if(document.querySelector('.student-tabs'))studentNavigation();
  }
  if(typeof syncAdminNavigation==='function'){
    const sync=syncAdminNavigation;
    syncAdminNavigation=function(){const result=sync.apply(this,arguments);document.querySelectorAll('#tabs [data-v]').forEach(b=>b.setAttribute('aria-current',b.dataset.v===ST.view?'page':'false'));return result;};
    document.getElementById('tabs')?.addEventListener('change',()=>window.scrollTo({top:0,behavior:'auto'}));
    document.getElementById('tabs')?.addEventListener('click',event=>{if(event.target.closest('[data-v]'))window.scrollTo({top:0,behavior:'auto'});});
    const menu=document.querySelector('.admin-section-nav');
    if(menu){const home=document.createElement('button');home.type='button';home.className='btn-sm';home.textContent='Overview';home.onclick=()=>{ST.view='overview';syncAdminNavigation();render();window.scrollTo({top:0,behavior:'auto'});};menu.append(home);}
  }
})();

const base=require('./playwright.config.cjs');
module.exports={...base,testMatch:'exam-assignments.spec.cjs',testIgnore:[],timeout:45000,workers:2,maxFailures:3,
 use:{...base.use,timezoneId:'Africa/Cairo',screenshot:'only-on-failure'},
 projects:[
  {name:'chromium-desktop',use:{browserName:'chromium',viewport:{width:1280,height:800}}},
  {name:'chromium-tablet',use:{browserName:'chromium',viewport:{width:820,height:1180},hasTouch:true}},
  {name:'chromium-mobile',use:{browserName:'chromium',viewport:{width:390,height:844},isMobile:true,hasTouch:true}},
  {name:'chromium-narrow',use:{browserName:'chromium',viewport:{width:320,height:568},isMobile:true,hasTouch:true}},
  {name:'chromium-landscape',use:{browserName:'chromium',viewport:{width:844,height:390},isMobile:true,hasTouch:true}},
  {name:'firefox-desktop',use:{browserName:'firefox',viewport:{width:1280,height:800}}},
  {name:'firefox-narrow',use:{browserName:'firefox',viewport:{width:390,height:844}}},
  {name:'webkit-desktop',use:{browserName:'webkit',viewport:{width:1280,height:800}}},
  {name:'webkit-mobile',use:{browserName:'webkit',viewport:{width:390,height:844},isMobile:true,hasTouch:true}}
 ].flatMap(project=>[project,{...project,name:'deployed-'+project.name,metadata:{deployedLayout:true}}])};

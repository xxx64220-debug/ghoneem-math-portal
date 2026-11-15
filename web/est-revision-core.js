(function(root){
 'use strict';
 const commonTopics=[
  ['Algebra & equations',['Algebraic expressions and equations','Systems of equations','Inequalities and absolute value']],
  ['Lines & functions',['Linear functions and slope','Functions and transformations']],
  ['Quadratics & polynomials',['Quadratics and polynomials','Polynomial division and remainder']],
  ['Ratios & percentages',['Ratios, percentages and unit conversion']],
  ['Statistics & probability',['Statistics and data analysis','Probability and conditional probability']],
  ['Triangles & trigonometry',['Triangles and similarity','Trigonometry','Angles and polygons']],
  ['Circles & measurement',['Circles','Area and perimeter','Volume and surface area']]
 ];
 const courses={
  est:{name:'EST I Math',examDate:'2026-12-11',dateLabel:'Friday · 11 December 2026',format:'50 multiple-choice questions · 75 minutes',intro:'Prepare for the 11 December EST I Math examination. Build reliable methods, close your topic gaps and practise at a steady pace.',
   stages:[
    ['2026-11-08','8–15 November','Secure the foundations','Review algebra, equations, inequalities, percentages and ratios. Use recent errors to choose two priorities.'],
    ['2026-11-16','16–22 November','Connect algebra and data','Practise functions, quadratics, exponents, statistics and probability. Explain your corrections after each assigned set.'],
    ['2026-11-23','23–29 November','Bring geometry together','Revisit triangles, circles, coordinate geometry, trigonometry, area and volume. Complete your assigned timed mock and review it.'],
    ['2026-11-30','30 November–6 December','Mix skills under time','Use assigned mixed practice and a timed mock. Check units, question wording and time management; identify two remaining weaknesses.'],
    ['2026-12-07','7–10 December','Correct, retest and settle','Finish mock corrections, retest the weakest skills and review key formulas. Keep the final day light and check exam arrangements.']
   ],topics:[...commonTopics,['Exponents & number skills',['Exponents, radicals and growth','Complex numbers']],['Other assigned algebra',['Logic and sets','Matrices']]]},
  est2:{name:'EST II Math',examDate:'2026-12-12',dateLabel:'Saturday · 12 December 2026',format:'40 multiple-choice questions · 60 minutes',intro:'Prepare for the 12 December EST II Math examination. Follow your assigned course and personal plan, then use focused practice to strengthen the skills that need work.',
   stages:[
    ['2026-11-08','8–15 November','Rebuild the core methods','Review algebra, systems, quadratics and polynomial forms. Revisit circle methods and the first incorrect step in recent work.'],
    ['2026-11-16','16–22 November','Work confidently with functions','Practise domain, transformations, inverses, exponents, radicals and logarithms from your assigned course. Explain the method before calculating.'],
    ['2026-11-23','23–29 November','Connect geometry and data','Revise coordinate geometry, triangles, trigonometry, statistics and probability. Complete an assigned mock, then correct its two weakest areas.'],
    ['2026-11-30','30 November–6 December','Refine mixed problem solving','Combine functions, algebra, geometry and measurement in assigned timed sets. Check complex-number work and calculator methods.'],
    ['2026-12-07','7–11 December','Finish with evidence','Complete your assigned final mock early, correct it and retest recurring errors. Keep 11 December light, especially if you also sit EST I.']
   ],topics:[...commonTopics,['Exponents & logarithms',['Exponents, radicals and growth','Logarithms and exponentials']],['Complex numbers & sets',['Complex numbers','Logic and sets']]]}
 };
 function track(value){return value==='est2'?'est2':'est';}
 function day(now=new Date()){return new Intl.DateTimeFormat('en-CA',{timeZone:'Africa/Cairo',year:'numeric',month:'2-digit',day:'2-digit'}).format(now);}
 function campaign(value,date=day()){
  const course=courses[track(value)],days=Math.round((Date.parse(course.examDate+'T00:00:00Z')-Date.parse(date+'T00:00:00Z'))/86400000);
  const phase=date<course.stages[0][0]||date>=course.examDate?-1:course.stages.reduce((index,stage,i)=>date>=stage[0]?i:index,-1);
  return {days,phase,state:days<0?'finished':days===0?'exam':'preparing'};
 }
 function activityLink(value,activity,lesson){const p=new URLSearchParams({study_track:track(value),study_activity:activity});if(lesson)p.set('study_lesson',lesson);return '/?'+p;}
 const api={courses,track,day,campaign,activityLink};if(typeof module!=='undefined'&&module.exports)module.exports=api;else root.ESTRevision=api;
})(typeof window==='undefined'?globalThis:window);

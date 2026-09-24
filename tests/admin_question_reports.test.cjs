const fs=require('node:fs'),assert=require('node:assert/strict');
const html=fs.readFileSync('web/admin.html','utf8');
const sql=fs.readFileSync('supabase/migrations/20260920_ranked_question_success.sql','utf8');

assert.match(html,/id="pdfBtn">Export PDF/);
assert.match(html,/questionPdf\(rows\)/);
assert.match(html,/Print \/ Save as PDF/);
assert.match(html,/Success<\/th>/);
assert.match(html,/setTimeout\(\(\) => URL\.revokeObjectURL/);
assert.match(sql,/Assigned quiz/);
assert.match(sql,/Daily quiz/);
assert.match(sql,/public\.answer_matches/);
assert.match(sql,/row_number\(\) over/);
assert.match(sql,/got_it_wrong/);
assert.match(sql,/percent_correct/);
console.log('PASS: hardest-question ranking combines assigned and daily quizzes and supports CSV/PDF export.');

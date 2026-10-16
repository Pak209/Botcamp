#!/usr/bin/env node
// Converts ../get-up-to-speed/content.js (+ content/units-1-3.overlay.json) into Botcamp/Resources/course.json.
// Usage: node scripts/build-course.mjs [path/to/content.js]
import fs from 'node:fs'; import vm from 'node:vm'; import path from 'node:path'; import {fileURLToPath} from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const src = process.argv[2] || path.resolve(root, '../get-up-to-speed/content.js');
const ctx = {}; vm.createContext(ctx);
vm.runInContext(fs.readFileSync(src, 'utf8') + '\n;globalThis.__out={MODULES,RUNGS,GLOSSARY,LAST_CHECKED};', ctx);
const {MODULES, RUNGS, GLOSSARY, LAST_CHECKED} = ctx.__out;
const overlay = JSON.parse(fs.readFileSync(path.join(root, 'content/units-1-3.overlay.json'), 'utf8'));
const strip = h => h.replace(/<br\s*\/?>/g, ' ').replace(/<[^>]+>/g, '').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&').replace(/\s+/g, ' ').trim();
const lead = b => { const m = b.match(/<p class="lead">([\s\S]*?)<\/p>/); return m ? strip(m[1]) : ''; };
const FREE = new Set(['m1', 'm2', 'm3']); // Dan: basics, models, prompting are free
const quizStep = q => ({type: 'choice', question: q[0], options: q[1], answer: q[2], explain: q[3]});
const handoff = m => ({type: 'handoff', intro: m.tryit.intro, prompt: m.tryit.prompts.join('\n\n'),
  checklist: ['I pasted the prompt into my AI app', 'I read the whole answer', 'I compared it with what I expected', 'I noticed one thing I would change next time']});
const units = MODULES.map((m, i) => {
  const ov = overlay[m.id];
  const base = {id: m.id, number: i + 1, title: ov?.title || m.title, subtitle: m.title, blurb: strip(m.blurb), rung: m.rung, isFree: FREE.has(m.id)};
  if (!ov) return {...base, isStub: true, lessons: [{id: `${m.id}-preview`, title: 'Preview', xp: 10, steps: [
    {type: 'explain', title: m.title, text: lead(m.body) || strip(m.blurb), note: 'Full lessons are coming in a later update.'}]}]};
  const lessons = ov.lessons.map(l => {
    if (l.handoffFromTryit) return {id: l.id, title: l.title, xp: 20, steps: [handoff(m)]};
    if (l.unitCheck) return {id: l.id, title: l.title, xp: 25, isUnitCheck: true, passFraction: 0.7, steps: [
      ...m.quiz.map(quizStep),
      {type: 'multiSelect', question: 'Which are common mistakes here?', options: [...m.mistakes.map(strip), 'Taking a short break'], answers: m.mistakes.map((_, j) => j), explain: 'All of these trip up beginners.'}]};
    return {xp: 10, ...l};
  });
  return {...base, isStub: false, lessons};
});
const course = {version: 1, lastChecked: LAST_CHECKED, generatedFrom: 'get-up-to-speed/content.js',
  rungs: RUNGS.map(([title, detail, unitId]) => ({title, detail, unitId})),
  units, glossary: GLOSSARY.map(([term, definition, unitId]) => ({term, definition, unitId}))};
const out = path.join(root, 'Botcamp/Resources/course.json');
fs.writeFileSync(out, JSON.stringify(course, null, 1));
console.log(`wrote ${out}: ${units.length} units, ${units.reduce((a, u) => a + u.lessons.length, 0)} lessons, ${course.glossary.length} glossary terms`);

import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
const s=fs.readFileSync('scripts/import_phase4_supabase.mjs','utf8');
test('phase4 importer uses deterministic primary-key upserts in dependency order',()=>{assert.match(s,/upsert\(batch,\{onConflict:'id'\}\)/);const a=s.indexOf("'courses',data.courses");const b=s.indexOf("'course_tees',data.course_tees");const c=s.indexOf("'course_holes',data.course_holes");assert.ok(a<b&&b<c)});
test('phase4 importer requires server-side test service credential and supports dry-run',()=>{assert.match(s,/SUPABASE_TEST_SERVICE_ROLE_KEY/);assert.match(s,/--dry-run/);assert.match(s,/DRY RUN OK/)});
test('phase4 importer validates fixed conservative counts and 18-hole SI sequences',()=>{assert.match(s,/courses: 460/);assert.match(s,/course_tees: 2273/);assert.match(s,/course_holes: 3888/);assert.match(s,/routing_groups: 216/);assert.match(s,/invalid stroke indexes/)});

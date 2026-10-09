import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const migrationPath = 'supabase/migrations/20260930000300_phase4_round_snapshots.sql';
const sql = fs.readFileSync(migrationPath, 'utf8').toLowerCase();

function has(re, message) {
  assert.match(sql, re, message);
}

test('migration 12 creates both round snapshot tables', () => {
  has(/create table if not exists public\.round_course_snapshot/, 'round_course_snapshot missing');
  has(/create table if not exists public\.round_hole_snapshot/, 'round_hole_snapshot missing');
});

test('course snapshot freezes required course and tee values', () => {
  for (const column of [
    'round_id', 'source_course_id', 'source_course_tee_id', 'course_name',
    'tee_name', 'gender_rating', 'course_rating', 'slope_rating', 'par'
  ]) assert.ok(sql.includes(column), `missing ${column}`);
});

test('hole snapshot constrains hole identity and stroke index uniqueness', () => {
  has(/primary key\s*\(round_id,\s*hole_number\)/s, 'round/hole primary key missing');
  has(/unique\s*\(round_id,\s*stroke_index\)/s, 'round/SI uniqueness missing');
  has(/hole_number integer not null check \(hole_number between 1 and 18\)/, 'hole number range missing');
  has(/stroke_index integer not null check \(stroke_index between 1 and 18\)/, 'SI range missing');
});

test('snapshot tables have RLS and read-only application policies', () => {
  has(/alter table public\.round_course_snapshot enable row level security/, 'course snapshot RLS missing');
  has(/alter table public\.round_hole_snapshot enable row level security/, 'hole snapshot RLS missing');
  has(/round_course_snapshot_read[\s\S]*for select to authenticated/, 'authenticated course snapshot read policy missing');
  has(/round_hole_snapshot_read[\s\S]*for select to authenticated/, 'authenticated hole snapshot read policy missing');
  assert.doesNotMatch(sql, /create policy[\s\S]{0,200}for (insert|update|delete) to authenticated/, 'authenticated direct snapshot writes must not be permitted');
});

test('snapshot creation is controlled, organiser-only and non-overwriting', () => {
  has(/create or replace function public\.snapshot_round_course\(p_round_id uuid\)/, 'snapshot function missing');
  has(/security definer/, 'snapshot function must be security definer');
  has(/not public\.is_tour_organiser\(v_round\.tour_id\)/, 'organiser authorization missing');
  has(/round course snapshot already exists/, 'existing snapshot refusal missing');
  has(/revoke all on function public\.snapshot_round_course\(uuid\) from public/, 'PUBLIC execute revoke missing');
  has(/grant execute on function public\.snapshot_round_course\(uuid\) to authenticated/, 'authenticated execute grant missing');
});

test('snapshot function rejects incomplete or malformed scoring routings', () => {
  has(/v_hole_count <> 18/, '18-hole count validation missing');
  has(/v_hole_number_count <> 18/, 'distinct hole number validation missing');
  has(/v_si_count <> 18/, 'distinct SI validation missing');
  has(/hole_number not between 1 and 18/, 'hole number validity check missing');
  has(/stroke_index not between 1 and 18/, 'SI validity check missing');
  has(/par not between 3 and 6/, 'hole par validity check missing');
});

test('snapshot function copies authoritative master values into immutable rows', () => {
  has(/insert into public\.round_course_snapshot[\s\S]*v_course\.name[\s\S]*v_tee\.tee_name[\s\S]*v_tee\.course_rating[\s\S]*v_tee\.slope_rating[\s\S]*v_tee\.par/, 'course/tee master copy missing');
  has(/insert into public\.round_hole_snapshot[\s\S]*select p_round_id, hole_number, par, stroke_index, metres[\s\S]*from public\.course_holes/, 'hole master copy missing');
});

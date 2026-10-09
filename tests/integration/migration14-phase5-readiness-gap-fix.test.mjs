import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const sql = fs.readFileSync('supabase/migrations/20261003000200_phase5_readiness_gap_fix.sql','utf8').toLowerCase();
const has=(re,msg)=>assert.match(sql,re,msg);

test('replaces Tour readiness validator rather than mutating Migration 13',()=>{
  has(/create or replace function public\.validate_tour_ready\(p_tour_id uuid\)/,'validator replacement missing');
});
test('every Round requires at least one active Round player',()=>{
  has(/from public\.round_players rp[\s\S]*rp\.round_id=v_round\.id and rp\.active/,'active Round-player query missing');
  has(/if v_active_round_players=0[\s\S]*must have active round players/,'zero active-player rejection missing');
});
test('every Round requires at least one match',()=>{
  has(/from public\.matches m[\s\S]*m\.round_id=v_round\.id/,'Round match count missing');
  has(/if v_match_count=0[\s\S]*must have at least one match/,'zero-match rejection missing');
});
test('existing Phase 5A readiness controls remain intact',()=>{
  has(/v_team_count<>2/,'two-team validation lost');
  has(/mod\(v_player_count,2\)<>0/,'even-player validation lost');
  has(/handicap_index is null/,'HI validation lost');
  has(/selected tee is not scoring-ready/,'course readiness lost');
  has(/perform public\.validate_round_pairings\(v_round\.id\)/,'pairing validation lost');
});
test('readiness remains organiser-controlled',()=>{
  has(/not public\.is_tour_organiser\(p_tour_id\)/,'organiser check missing');
  has(/revoke all on function public\.validate_tour_ready\(uuid\) from public/,'PUBLIC revoke missing');
  has(/grant execute on function public\.validate_tour_ready\(uuid\) to authenticated/,'authenticated execute grant missing');
});

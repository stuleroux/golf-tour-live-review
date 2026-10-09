import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";

const sql = fs
  .readFileSync(
    "supabase/migrations/20261005000200_phase5_round_player_rls.sql",
    "utf8"
  )
  .toLowerCase();

const has = (regex, message) => assert.match(sql, regex, message);

test("round_players keeps RLS enabled", () => {
  has(
    /alter table public\.round_players enable row level security/,
    "round_players RLS missing"
  );
});

test("authenticated Tour members can read Round players through the parent Tour", () => {
  has(/create policy round_players_read/, "read policy missing");
  has(/for select\s+to authenticated/, "authenticated SELECT policy missing");
  has(/public\.can_read_tour\(r\.tour_id\)/, "Tour read authorization missing");
  has(/r\.id\s*=\s*round_players\.round_id/, "Round-to-Tour scope missing");
});

test("only the organiser can write Round-player setup rows", () => {
  has(/create policy round_players_org_all/, "organiser policy missing");
  has(/for all\s+to authenticated/, "organiser ALL policy missing");
  const organiserChecks = sql.match(/public\.is_tour_organiser\(r\.tour_id\)/g) ?? [];
  assert.equal(
    organiserChecks.length,
    2,
    "organiser authorization must protect both USING and WITH CHECK"
  );
});

test("organiser write policy has both USING and WITH CHECK", () => {
  has(
    /create policy round_players_org_all[\s\S]*using \([\s\S]*\)[\s\S]*with check \(/,
    "organiser policy must protect existing and new rows"
  );
});

test("migration does not add anonymous or spectator access", () => {
  assert.doesNotMatch(sql, /to anon/);
  assert.doesNotMatch(sql, /spectator_enabled/);
});

test("migration does not grant or depend on service_role bypass", () => {
  assert.doesNotMatch(sql, /grant .*service_role/);
  assert.doesNotMatch(sql, /to service_role/);
});

test("authenticated table grants remain explicit", () => {
  has(
    /grant select, insert, update, delete on public\.round_players to authenticated/,
    "authenticated grants missing"
  );
});

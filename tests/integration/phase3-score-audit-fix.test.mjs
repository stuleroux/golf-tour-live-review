import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const fix = readFileSync("supabase/migrations/20260929000700_fix_score_audit_trigger.sql", "utf8");

test("score audit fix uses match_id for match confirmations", () => {
  assert.match(fix, /tg_table_name = 'match_confirmations'/);
  assert.match(fix, /entity_uuid := old\.match_id/);
  assert.match(fix, /entity_uuid := new\.match_id/);
  assert.match(fix, /entity_uuid := old\.id/);
  assert.match(fix, /entity_uuid := new\.id/);
  assert.match(fix, /match_id_value := old\.match_id/);
  assert.match(fix, /match_id_value := new\.match_id/);
  assert.match(fix, /return old/);
  assert.match(fix, /return new/);
});

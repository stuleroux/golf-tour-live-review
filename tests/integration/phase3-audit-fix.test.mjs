import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const fix = readFileSync("supabase/migrations/20260929000600_fix_audit_trigger.sql", "utf8");

test("audit trigger fix branches by table before referencing row fields", () => {
  assert.match(fix, /if tg_table_name = 'tours'/);
  assert.match(fix, /elsif tg_table_name = 'teams'/);
  assert.match(fix, /elsif tg_table_name = 'tour_players'/);
  assert.match(fix, /elsif tg_table_name = 'rounds'/);
  assert.match(fix, /if tg_op = 'DELETE'/);
  assert.match(fix, /return old/);
  assert.match(fix, /return new/);
});

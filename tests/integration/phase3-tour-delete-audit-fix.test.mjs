import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const fix = readFileSync("supabase/migrations/20260929000800_fix_tour_delete_audit.sql", "utf8");

test("tour delete audit drops FK reference but preserves deleted identity", () => {
  assert.match(fix, /if tg_table_name = 'tours'/);
  assert.match(fix, /if tg_op = 'DELETE'/);
  assert.match(fix, /v_tour := null/);
  assert.match(fix, /v_entity_id := old\.id/);
  assert.match(fix, /to_jsonb\(old\)/);
  assert.match(fix, /return old/);
});

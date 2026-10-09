import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
const sql=readFileSync("supabase/migrations/20260929000900_fix_audit_tour_history.sql","utf8");
test("audit history survives tour deletion",()=>{
 assert.match(sql,/drop constraint if exists audit_log_tour_id_fkey/);
 assert.match(sql,/v_tour := old\.id/);
 assert.match(sql,/v_tour := old\.tour_id/);
 assert.doesNotMatch(sql,/v_tour := null/);
});

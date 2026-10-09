import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";

const sql = fs
  .readFileSync(
    "supabase/migrations/20261005000100_phase5b_draft_round_players.sql",
    "utf8"
  )
  .toLowerCase();

const script = fs.readFileSync(
  "scripts/phase5b-tour-start.mjs",
  "utf8"
);

const has = (regex, message) => assert.match(sql, regex, message);

test("draft Round players allow null handicap snapshots", () => {
  has(
    /alter column frozen_tour_handicap_index drop not null/,
    "frozen HI remains mandatory"
  );
  has(
    /alter column course_handicap drop not null/,
    "CH remains mandatory"
  );
  has(
    /frozen_tour_handicap_index is null\) = \(course_handicap is null/,
    "pair nullability constraint missing"
  );
});

test("finalised Round handicap snapshot is immutable", () => {
  has(
    /round handicap snapshot is immutable once set/,
    "immutability protection missing"
  );
});

test("Tour start remains organiser-controlled and validated", () => {
  has(
    /not public\.is_tour_organiser\(p_tour_id\)/,
    "organiser check missing"
  );
  has(
    /perform public\.validate_tour_ready\(p_tour_id\)/,
    "readiness validation missing"
  );
  has(
    /status not in \('draft','published'\)/,
    "status gate missing"
  );
});

test("Tour start freezes Tour HIs and requires exact active Round-player payload", () => {
  has(
    /set frozen_handicap_index=handicap_index/,
    "Tour HI freeze missing"
  );
  has(
    /v_input_count<>v_expected_count/,
    "exact payload count missing"
  );
  has(/duplicate round players/, "duplicate protection missing");
});

test("Tour start requires Round course snapshots and finalised handicap snapshots", () => {
  has(/round_course_snapshot/, "course snapshot requirement missing");
  has(
    /every active round player must have a finalised handicap snapshot/,
    "finalisation check missing"
  );
});

test("Course Handicap stays in the TypeScript domain engine", () => {
  assert.match(
    script,
    /import \{ calculateCourseHandicap \} from ["']\.\.\/src\/domain\/handicap\/index\.ts["']/
  );
  assert.match(script, /calculateCourseHandicap\(/);
  assert.doesNotMatch(sql, /slope_rating\s*\/\s*113|\/113/);
});

test("Tour start transitions status only after finalisation work", () => {
  const finalised = sql.indexOf(
    "every active round player must have a finalised handicap snapshot"
  );
  const statusUpdate = sql.indexOf(
    "update public.tours set status='live'"
  );
  assert.ok(finalised >= 0 && statusUpdate > finalised);
});

test(
  "Tour start loads Round snapshots explicitly by round_id instead of assuming a direct PostgREST relationship",
  () => {
    assert.doesNotMatch(script, /round_course_snapshot!inner/);
    assert.match(
      script,
      /\.from\(["']round_course_snapshot["']\)/
    );
    assert.match(
      script,
      /\.in\(["']round_id["'],\s*roundIds\)/
    );
    assert.match(script, /snapshotByRound\s*=\s*new Map/);
  }
);

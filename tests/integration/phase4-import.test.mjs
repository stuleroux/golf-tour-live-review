import test from "node:test";import assert from "node:assert/strict";import fs from "node:fs";
function lines(p){return fs.readFileSync(p,"utf8").trim().split(/\r?\n/)}
test("phase4 conservative export counts",()=>{assert.equal(lines("data/courses.csv").length-1,460);assert.equal(lines("data/course_tees.csv").length-1,2273);assert.equal(lines("data/course_holes.csv").length-1,3888)});
test("every validated routing has exactly 18 holes",()=>{const rows=lines("data/course_holes.csv").slice(1);const counts=new Map();for(const r of rows){const cols=r.split(',');const k=cols[1];counts.set(k,(counts.get(k)||0)+1)}assert.equal(counts.size,216);for(const n of counts.values())assert.equal(n,18)});

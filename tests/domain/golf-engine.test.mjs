import test from "node:test";import assert from "node:assert/strict";import{readFileSync}from"node:fs";import ts from"typescript";import vm from"node:vm";import path from"node:path";
function loadTs(file,deps={}){const source=readFileSync(file,"utf8");const js=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;const mod={exports:{}};vm.runInNewContext(`(function(require,module,exports){${js}\n})`,{console})((id)=>deps[id]??require(id),mod,mod.exports);return mod.exports;}
const root=process.cwd();const H=loadTs(path.join(root,"src/domain/handicap/index.ts"));const S=loadTs(path.join(root,"src/domain/scoring/index.ts"));const M=loadTs(path.join(root,"src/domain/matchplay/index.ts"),{"../scoring":{}});const C=loadTs(path.join(root,"src/domain/concessions/index.ts"));const T=loadTs(path.join(root,"src/domain/tour/index.ts"));
test("golf handicap notation",()=>{assert.equal(H.parseGolfHandicap("+2"),-2);assert.equal(H.formatGolfHandicap(-5),"+5");});
test("explicit golf rounding",()=>{assert.equal(H.golfRound(12.5),13);assert.equal(H.golfRound(-1.5),-1);assert.equal(H.golfRound(0.5),1);});
test("stroke allocation ordinary/high",()=>{assert.equal(H.strokesOnHole(10,3),1);assert.equal(H.strokesOnHole(10,14),0);assert.equal(H.strokesOnHole(32,3),2);assert.equal(H.strokesOnHole(32,17),1);assert.equal(H.strokesOnHole(37,1),3);assert.equal(H.strokesOnHole(37,18),2);});
test("plus handicap gives strokes on highest SI holes",()=>{assert.equal(H.strokesOnHole(-3,18),-1);assert.equal(H.strokesOnHole(-3,16),-1);assert.equal(H.strokesOnHole(-3,15),0);});
test("handicap modes",()=>{assert.equal(JSON.stringify(H.applyHandicapMode([-2,8],"FULL")),JSON.stringify([-2,8]));assert.equal(JSON.stringify(H.applyHandicapMode([-2,8],"PLAY_OFF_LOWEST")),JSON.stringify([0,10]));assert.equal(JSON.stringify(H.applyHandicapMode([-2,8],"SCRATCH")),JSON.stringify([0,0]));});
test("scramble format handicaps",()=>{assert.equal(JSON.stringify(H.scrambleDriveFormatHandicaps(10,18)),JSON.stringify([10,14]));assert.equal(JSON.stringify(H.scrambleDriveFormatHandicaps(9,16)),JSON.stringify([9,13]));assert.equal(JSON.stringify(H.scrambleDriveFormatHandicaps(-2,10)),JSON.stringify([-2,4]));});
test("alternate shot pair handicap",()=>{assert.equal(H.alternateShotPairHandicap(10,18),14);assert.equal(H.alternateShotPairHandicap(9,16),13);assert.equal(H.alternateShotPairHandicap(-3,4),1);});
test("score ceiling",()=>{assert.equal(JSON.stringify(S.scoreLimit(4,0)),JSON.stringify({maxExact:5,overflow:6}));assert.equal(JSON.stringify(S.scoreLimit(4,1)),JSON.stringify({maxExact:6,overflow:7}));assert.equal(JSON.stringify(S.scoreLimit(4,2)),JSON.stringify({maxExact:7,overflow:8}));});
test("betterball acceptance example",()=>{const blue=S.betterballScore([S.netScore(5,1),S.netScore(6,1)]);const red=S.betterballScore([S.netScore(4,0),S.netScore(6,2)]);assert.equal(blue,4);assert.equal(red,4);assert.equal(S.compareScores(blue,red),"HALVED");});
test("match decides 5 and 4",()=>{const state=M.calculateMatchState(["A","A","A","A","A",...Array(9).fill("HALVED")],18);assert.equal(state.decided,true);assert.equal(state.display,"5 & 4");assert.equal(state.holesPlayed,14);});
test("front nine concession max result",()=>assert.equal(C.manufacturedConcessionResult(7),"10 & 8"));
test("back nine concession option A",()=>{assert.equal(C.manufacturedConcessionResult(13),"6 & 5");assert.equal(C.manufacturedConcessionResult(17),"2 & 1");});
test("tour projection",()=>assert.equal(JSON.stringify(T.projectTourScore({a:6.5,b:5.5},[{pointsValue:1,state:"A"},{pointsValue:1,state:"AS"},{pointsValue:1,state:"B"},{pointsValue:1,state:"A"}])),JSON.stringify({a:9,b:7})));

test("plus handicap depths",()=>{
  assert.equal(H.strokesOnHole(-5,18),-1); assert.equal(H.strokesOnHole(-5,14),-1); assert.equal(H.strokesOnHole(-5,13),0);
  assert.equal(H.strokesOnHole(-18,1),-1); assert.equal(H.strokesOnHole(-18,18),-1);
});

test("singles full scoring",()=>{
  assert.equal(S.scoreSinglesHole({gross:5,strokes:H.strokesOnHole(10,5)},{gross:4,strokes:H.strokesOnHole(1,5)}),"HALVED");
});

test("every handicap mode handles ordinary and plus players",()=>{
  assert.equal(JSON.stringify(H.applyHandicapMode([-2,6,10,18],"FULL")),JSON.stringify([-2,6,10,18]));
  assert.equal(JSON.stringify(H.applyHandicapMode([-2,6,10,18],"PLAY_OFF_LOWEST")),JSON.stringify([0,8,12,20]));
  assert.equal(JSON.stringify(H.applyHandicapMode([-2,6,10,18],"SCRATCH")),JSON.stringify([0,0,0,0]));
});

test("betterball scoring strategy",()=>{
  const r=S.scoreBetterballHole([{gross:5,strokes:1},{gross:6,strokes:1}],[{gross:4,strokes:0},{gross:6,strokes:2}]);
  assert.equal(JSON.stringify(r),JSON.stringify({sideANet:4,sideBNet:4,winner:"HALVED"}));
});

test("scramble mode applies after format adjustment",()=>{
  const f=[...H.scrambleDriveFormatHandicaps(10,18),...H.scrambleDriveFormatHandicaps(6,20)];
  assert.equal(JSON.stringify(f),JSON.stringify([10,14,6,13]));
  assert.equal(JSON.stringify(H.applyHandicapMode(f,"FULL")),JSON.stringify([10,14,6,13]));
  assert.equal(JSON.stringify(H.applyHandicapMode(f,"PLAY_OFF_LOWEST")),JSON.stringify([4,8,0,7]));
  assert.equal(JSON.stringify(H.applyHandicapMode(f,"SCRATCH")),JSON.stringify([0,0,0,0]));
});

test("scramble scoring uses independent better balls after drive selection",()=>{
  const r=S.scoreScrambleDriveHole([{gross:4,strokes:1},{gross:6,strokes:1}],[{gross:4,strokes:0},{gross:5,strokes:2}]);
  assert.equal(r.winner,"HALVED"); assert.equal(r.sideANet,3); assert.equal(r.sideBNet,3);
});

test("alternate shot modes and scoring",()=>{
  const pairs=[H.alternateShotPairHandicap(10,18),H.alternateShotPairHandicap(6,12)];
  assert.equal(JSON.stringify(H.applyHandicapMode(pairs,"FULL")),JSON.stringify([14,9]));
  assert.equal(JSON.stringify(H.applyHandicapMode(pairs,"PLAY_OFF_LOWEST")),JSON.stringify([5,0]));
  assert.equal(JSON.stringify(H.applyHandicapMode(pairs,"SCRATCH")),JSON.stringify([0,0]));
  assert.equal(S.scoreAlternateShotHole({gross:5,strokes:1},{gross:4,strokes:0}),"HALVED");
});

test("alternate shot odd even tee rotation",()=>{
  assert.equal(M.teePlayerForHole("Stu","James",1),"Stu"); assert.equal(M.teePlayerForHole("Stu","James",2),"James");
  assert.equal(M.teePlayerForHole("Stu","James",17),"Stu"); assert.equal(M.teePlayerForHole("Stu","James",18),"James");
});

test("nine-hole early finish",()=>{
  const state=M.calculateMatchState(["A","A","A","A","HALVED","HALVED"],9);
  assert.equal(state.decided,true); assert.equal(state.display,"4 & 3");
});

test("decided match keeps original result and scorecard may continue",()=>{
  const state=M.calculateMatchState(["A","A","A","A","A",...Array(9).fill("HALVED"),"B","B","B","B"],18);
  assert.equal(state.display,"5 & 4"); assert.equal(state.holesPlayed,14); assert.equal(M.scorecardCanContinueAfterDecision(state),true);
});

test("previous-hole correction recalculates match",()=>{
  const before=M.calculateMatchState(["A","A","HALVED","HALVED","HALVED","HALVED"],18);
  const after=M.calculateMatchState(["A","HALVED","HALVED","HALVED","HALVED","HALVED"],18);
  assert.equal(before.lead,2); assert.equal(after.lead,1);
});

test("tour tie and victory target",()=>{
  assert.equal(T.tourIsTied({a:4,b:4}),true); assert.equal(T.pointsRequiredForOutrightWin(8),5); assert.equal(T.pointsRequiredForOutrightWin(16),9);
});

test("concession boundary holes",()=>{
  assert.equal(C.manufacturedConcessionResult(1),"10 & 8"); assert.equal(C.manufacturedConcessionResult(9),"10 & 8");
  assert.equal(C.manufacturedConcessionResult(10),"9 & 8"); assert.equal(C.manufacturedConcessionResult(18),"1 & 0");
});

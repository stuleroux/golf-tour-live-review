export interface ScoreLimit{maxExact:number;overflow:number}
export function scoreLimit(par:number,strokesReceived:number):ScoreLimit{const effective=Math.max(0,strokesReceived);const maxExact=par+effective+1;return{maxExact,overflow:maxExact+1};}
export function netScore(gross:number,strokesReceived:number):number{return gross-strokesReceived;}
export function betterballScore(nets:number[]):number{if(!nets.length)throw new Error("At least one score is required");return Math.min(...nets);}
export type HoleWinner="A"|"B"|"HALVED";
export function compareScores(a:number,b:number):HoleWinner{return a<b?"A":b<a?"B":"HALVED";}

export interface IndividualHoleInput { gross: number; strokes: number }
export interface BetterballHoleResult { sideANet: number; sideBNet: number; winner: HoleWinner }
export interface AlternateShotHoleInput { gross: number; strokes: number }

export function scoreSinglesHole(a: IndividualHoleInput, b: IndividualHoleInput): HoleWinner {
  return compareScores(netScore(a.gross, a.strokes), netScore(b.gross, b.strokes));
}

export function scoreBetterballHole(a: IndividualHoleInput[], b: IndividualHoleInput[]): BetterballHoleResult {
  if (a.length !== 2 || b.length !== 2) throw new Error("Betterball requires exactly two scores per side");
  const sideANet = betterballScore(a.map((s) => netScore(s.gross, s.strokes)));
  const sideBNet = betterballScore(b.map((s) => netScore(s.gross, s.strokes)));
  return { sideANet, sideBNet, winner: compareScores(sideANet, sideBNet) };
}

export function scoreScrambleDriveHole(a: IndividualHoleInput[], b: IndividualHoleInput[]): BetterballHoleResult {
  return scoreBetterballHole(a, b);
}

export function scoreAlternateShotHole(a: AlternateShotHoleInput, b: AlternateShotHoleInput): HoleWinner {
  return compareScores(netScore(a.gross, a.strokes), netScore(b.gross, b.strokes));
}

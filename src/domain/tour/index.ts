export interface LiveMatchProjection{pointsValue:number;state:"A"|"B"|"AS"} export interface TeamPoints{a:number;b:number}
export function projectTourScore(confirmed:TeamPoints,live:LiveMatchProjection[]):TeamPoints{return live.reduce((score,match)=>{if(match.state==="A")score.a+=match.pointsValue;else if(match.state==="B")score.b+=match.pointsValue;else{score.a+=match.pointsValue/2;score.b+=match.pointsValue/2;}return score;},{...confirmed});}

export function tourIsTied(points: TeamPoints): boolean { return points.a === points.b; }
export function pointsRequiredForOutrightWin(totalAvailable: number): number {
  if (totalAvailable <= 0) throw new Error("Total available points must be positive");
  return Math.floor(totalAvailable / 2) + 1;
}

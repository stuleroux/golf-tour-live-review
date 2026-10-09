import type { HoleWinner } from "../scoring";
export interface MatchState{lead:number;holesPlayed:number;holesRemaining:number;decided:boolean;display:string}
export function calculateMatchState(results:HoleWinner[],totalHoles:number):MatchState{let lead=0;let decidedAt:number|null=null;let decidedLead=0;for(let i=0;i<results.length;i+=1){if(decidedAt!==null)break;lead+=results[i]==="A"?1:results[i]==="B"?-1:0;const remaining=totalHoles-(i+1);if(Math.abs(lead)>remaining){decidedAt=i+1;decidedLead=lead;}}const holesPlayed=decidedAt??results.length;const holesRemaining=totalHoles-holesPlayed;if(decidedAt!==null)return{lead:decidedLead,holesPlayed,holesRemaining,decided:true,display:`${Math.abs(decidedLead)} & ${holesRemaining}`};if(results.length>=totalHoles)return{lead,holesPlayed:totalHoles,holesRemaining:0,decided:true,display:lead===0?"HALVED":`${Math.abs(lead)} UP`};return{lead,holesPlayed,holesRemaining:totalHoles-holesPlayed,decided:false,display:lead===0?"AS":`${Math.abs(lead)} UP`};}

export function teePlayerForHole<T>(oddPlayer: T, evenPlayer: T, holeNumber: number): T {
  if (!Number.isInteger(holeNumber) || holeNumber < 1 || holeNumber > 18) throw new Error("Hole must be 1-18");
  return holeNumber % 2 === 1 ? oddPlayer : evenPlayer;
}

export function scorecardCanContinueAfterDecision(state: MatchState): boolean {
  return state.decided && state.holesRemaining > 0;
}

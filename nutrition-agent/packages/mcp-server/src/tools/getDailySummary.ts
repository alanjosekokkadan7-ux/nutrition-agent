import { getMealLogs, sumNutrition, roundNutrition } from "../data/mealStore.js";
export async function getDailySummary(userId: string, date?: string, goals: { calories?:number; protein?:number; carbs?:number; fat?:number } = {}) {
  const d = date ?? new Date().toISOString().slice(0,10);
  const logs = getMealLogs(userId, d);
  const totals = roundNutrition(sumNutrition(logs.map(l=>l.totals)));
  const cg=goals.calories??2000, pg=goals.protein??50, carg=goals.carbs??260, fg=goals.fat??65;
  const pct=(a:number,t:number)=>Math.round(a/t*100);
  const insights: string[] = [];
  if(pct(totals.calories,cg)>110) insights.push("⚠ Exceeded calorie goal");
  if(pct(totals.protein,pg)<60) insights.push("ℹ Protein intake is low");
  if(totals.sodium>2300) insights.push("⚠ Sodium above 2300mg limit");
  if(logs.length===0) insights.push("No meals logged yet for this date.");
  return { userId, date:d, mealsLogged:logs.length, totals, goals:{calories:cg,protein_g:pg,carbs_g:carg,fat_g:fg}, progress:{caloriesPct:pct(totals.calories,cg),proteinPct:pct(totals.protein,pg)}, insights };
}

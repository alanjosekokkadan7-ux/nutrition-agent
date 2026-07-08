import { searchFoods, scaleNutrition, type Nutrition } from "../data/foodDatabase.js";
import { sumNutrition, roundNutrition } from "../data/mealStore.js";
export async function analyzeMeal(desc: string, portionNotes?: string) {
  const full = portionNotes ? `${desc} ${portionNotes}` : desc;
  const segments = full.split(/,|with|and/i).map(s=>s.trim()).filter(Boolean);
  const found: { name:string; grams:number; nutrition:Nutrition }[] = [];
  for (const seg of segments) {
    const gm = seg.match(/(\d+)\s*g/i);
    const grams = gm ? parseInt(gm[1]) : 150;
    const match = searchFoods(seg.replace(/\d+\s*g/gi,"").trim(),1)[0];
    if (match) found.push({ name:match.name, grams, nutrition:scaleNutrition(match.per100g,grams) });
  }
  const totals = found.length > 0 ? roundNutrition(sumNutrition(found.map(i=>i.nutrition))) : roundNutrition({calories:0,protein:0,carbs:0,fat:0,fiber:0,sugar:0,sodium:0,calcium:0,iron:0,vitaminC:0,vitaminD:0,vitaminB12:0,potassium:0,magnesium:0,zinc:0,cholesterol:0,saturatedFat:0,omega3:0});
  let score = 50;
  score += Math.min(20, totals.protein*0.5); score += Math.min(15, totals.fiber*2); score += Math.min(10, totals.vitaminC*0.2);
  if(totals.sodium>600) score -= Math.min(15,(totals.sodium-600)/60); if(totals.saturatedFat>10) score -= Math.min(15,(totals.saturatedFat-10)*1.5);
  score = Math.max(0,Math.min(100,Math.round(score)));
  return { mealDescription:desc, ingredients:found.map(i=>({name:i.name,grams:i.grams,calories:Math.round(i.nutrition.calories)})), totals, healthScore:{ score, rating:score>=80?"Excellent":score>=60?"Good":score>=40?"Fair":"Poor" }, flags:[...(totals.sodium>800?["HIGH_SODIUM"]:[]),...(totals.fiber<3?["LOW_FIBER"]:[]),...(totals.protein>30?["HIGH_PROTEIN"]:[]),...(totals.omega3>1?["OMEGA3_RICH"]:[])], disclaimer:"Analysis based on matched food DB entries and estimated portions." };
}

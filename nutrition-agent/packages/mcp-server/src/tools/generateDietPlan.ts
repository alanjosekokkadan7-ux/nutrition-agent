import { searchFoods } from "../data/foodDatabase.js";
interface PlanParams { age:number; sex:string; weight_kg:number; height_cm:number; activity_level:string; goal:string; health_conditions?:string[]; allergies?:string[]; cuisine_preferences?:string[]; days?:number; }
const ACT: Record<string,number> = { sedentary:1.2, lightly_active:1.375, moderately_active:1.55, very_active:1.725, extra_active:1.9 };
const ADJ: Record<string,number> = { weight_loss:-500, maintenance:0, muscle_gain:300, endurance:200, general_health:0 };
function tdee(p: PlanParams) {
  const bmr = p.sex==="male" ? 10*p.weight_kg+6.25*p.height_cm-5*p.age+5 : 10*p.weight_kg+6.25*p.height_cm-5*p.age-161;
  return Math.round(bmr*(ACT[p.activity_level]??1.55)+(ADJ[p.goal]??0));
}
function macros(cal: number, goal: string) {
  let p=0.25,c=0.50,f=0.25;
  if(goal==="muscle_gain"){p=0.30;c=0.45;}
  if(goal==="weight_loss"){p=0.35;c=0.40;}
  if(goal==="endurance"){p=0.20;c=0.60;f=0.20;}
  return { calories:cal, protein_g:Math.round(cal*p/4), carbs_g:Math.round(cal*c/4), fat_g:Math.round(cal*f/9) };
}
const TEMPLATES = [
  { type:"breakfast", pct:0.25, foods:["oatmeal","egg","banana","greek yogurt"] },
  { type:"lunch",     pct:0.35, foods:["chicken breast","brown rice","broccoli"] },
  { type:"snack",     pct:0.10, foods:["almonds","apple","blueberries"] },
  { type:"dinner",    pct:0.30, foods:["salmon","quinoa","sweet potato","spinach"] },
];
export async function generateDietPlan(params: PlanParams) {
  const cal = tdee(params);
  const days = params.days ?? 3;
  const allergies = params.allergies ?? [];
  const mealPlan = Array.from({length:days},(_,i) => ({
    day: i+1, targetCalories: cal,
    meals: TEMPLATES.map(t => {
      const safe = t.foods.find(f => !allergies.some(a => f.includes(a.toLowerCase()))) ?? t.foods[0];
      const match = searchFoods(safe, 1)[0];
      return { type:t.type, targetCalories:Math.round(cal*t.pct), items: match ? [{ food:match.name, category:match.category }] : [] };
    })
  }));
  return { targetCalories:cal, macroTargets:macros(cal,params.goal), mealPlan, disclaimer:"Consult a registered dietitian for medical nutrition advice." };
}

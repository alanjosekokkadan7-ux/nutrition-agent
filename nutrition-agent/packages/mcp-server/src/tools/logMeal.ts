import { searchFoods, scaleNutrition } from "../data/foodDatabase.js";
import { saveMealLog, sumNutrition, roundNutrition } from "../data/mealStore.js";
import type { MealItem } from "../data/mealStore.js";
function makeId() { return Date.now().toString(36)+Math.random().toString(36).slice(2,8); }
function inferType(iso: string): "breakfast"|"lunch"|"dinner"|"snack" {
  const h = new Date(iso).getHours();
  if(h>=5&&h<11) return "breakfast"; if(h>=11&&h<15) return "lunch"; if(h>=15&&h<18) return "snack"; return "dinner";
}
export async function logMeal(userId: string, description: string, mealType?: "breakfast"|"lunch"|"dinner"|"snack", timestamp?: string) {
  const ts = timestamp ?? new Date().toISOString();
  const type = mealType ?? inferType(ts);
  const segments = description.split(/\band\b|,|with|plus/i).map(s=>s.trim()).filter(Boolean);
  const items: MealItem[] = [];
  for (const seg of segments) {
    const nm = seg.match(/^(\d+(?:\.\d+)?)\s*(g|grams?)?\s+(.+)/i);
    const grams = nm ? ((/g|gram/i.test(nm[2]??"")?parseFloat(nm[1]):parseFloat(nm[1])*150)) : 150;
    const raw = nm ? nm[3] : seg;
    const match = searchFoods(raw,1)[0];
    if (match) items.push({ name:match.name, grams, nutrition:scaleNutrition(match.per100g,grams) });
  }
  const totals = roundNutrition(sumNutrition(items.map(i=>i.nutrition)));
  const entry = { id:makeId(), userId, timestamp:ts, mealType:type, description, items, totals };
  saveMealLog(entry);
  const flags: string[] = [];
  if(totals.sodium>800) flags.push("⚠ High sodium"); if(totals.calories>900) flags.push("ℹ Calorie-dense");
  return { logged:true, entryId:entry.id, mealType:type, items:items.map(i=>({food:i.name,grams:i.grams,calories:i.nutrition.calories})), totals, flags };
}

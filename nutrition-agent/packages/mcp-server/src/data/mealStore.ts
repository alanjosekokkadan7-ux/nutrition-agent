import type { Nutrition } from "./foodDatabase.js";
export interface MealItem { name: string; grams: number; nutrition: Nutrition; }
export interface MealLogEntry { id: string; userId: string; timestamp: string; mealType: "breakfast"|"lunch"|"dinner"|"snack"; description: string; items: MealItem[]; totals: Nutrition; }
const store = new Map<string, Map<string, MealLogEntry[]>>();
export function saveMealLog(e: MealLogEntry) {
  const dk = e.timestamp.slice(0,10);
  if (!store.has(e.userId)) store.set(e.userId, new Map());
  const us = store.get(e.userId)!;
  if (!us.has(dk)) us.set(dk, []);
  us.get(dk)!.push(e);
}
export function getMealLogs(userId: string, date: string): MealLogEntry[] {
  return store.get(userId)?.get(date) ?? [];
}
export function sumNutrition(items: Nutrition[]): Nutrition {
  const z: Nutrition = { calories:0,protein:0,carbs:0,fat:0,fiber:0,sugar:0,sodium:0,calcium:0,iron:0,vitaminC:0,vitaminD:0,vitaminB12:0,potassium:0,magnesium:0,zinc:0,cholesterol:0,saturatedFat:0,omega3:0 };
  return items.reduce((a,n) => ({ calories:a.calories+n.calories, protein:a.protein+n.protein, carbs:a.carbs+n.carbs, fat:a.fat+n.fat, fiber:a.fiber+n.fiber, sugar:a.sugar+n.sugar, sodium:a.sodium+n.sodium, calcium:a.calcium+n.calcium, iron:a.iron+n.iron, vitaminC:a.vitaminC+n.vitaminC, vitaminD:a.vitaminD+n.vitaminD, vitaminB12:a.vitaminB12+n.vitaminB12, potassium:a.potassium+n.potassium, magnesium:a.magnesium+n.magnesium, zinc:a.zinc+n.zinc, cholesterol:a.cholesterol+n.cholesterol, saturatedFat:a.saturatedFat+n.saturatedFat, omega3:a.omega3+n.omega3 }), z);
}
export function roundNutrition(n: Nutrition): Nutrition {
  return Object.fromEntries(Object.entries(n).map(([k,v]) => [k, Math.round((v as number)*10)/10])) as unknown as Nutrition;
}

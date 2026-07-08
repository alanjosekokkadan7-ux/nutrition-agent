import { searchFoods, scaleNutrition } from "../data/foodDatabase.js";
export async function searchFoodNutrition(query: string, servingGrams: number) {
  const results = searchFoods(query, 5);
  if (results.length === 0) return { query, message: "No results found.", results: [] };
  return { query, servingGrams, results: results.map(food => ({ name: food.name, category: food.category, source: "USDA FoodData Central", per100g: food.per100g, perServing: { grams: servingGrams, ...scaleNutrition(food.per100g, servingGrams) }, tags: food.tags })) };
}

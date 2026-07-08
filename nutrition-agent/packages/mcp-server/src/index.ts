#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { searchFoodNutrition } from "./tools/searchFoodNutrition.js";
import { generateDietPlan } from "./tools/generateDietPlan.js";
import { logMeal } from "./tools/logMeal.js";
import { getDailySummary } from "./tools/getDailySummary.js";
import { analyzeMeal } from "./tools/analyzeMeal.js";
import { getNutrientRecommendations } from "./tools/getNutrientRecommendations.js";

const server = new McpServer({ name: "nutrition-agent", version: "1.0.0" });

server.tool("search_food_nutrition",
  "Search nutritional values of any food item (RAG). Returns calories, macros, vitamins per 100g and per serving.",
  { query: z.string(), serving_grams: z.number().optional() },
  async ({ query, serving_grams }) => {
    try {
      const r = await searchFoodNutrition(query, serving_grams ?? 100);
      return { content: [{ type: "text", text: JSON.stringify(r, null, 2) }] };
    } catch (e) { return { content: [{ type: "text", text: String(e) }], isError: true }; }
  }
);

server.tool("generate_diet_plan",
  "Create a personalized multi-day meal plan based on user profile, health conditions, and goals.",
  {
    age: z.number(), sex: z.enum(["male","female","other"]),
    weight_kg: z.number(), height_cm: z.number(),
    activity_level: z.enum(["sedentary","lightly_active","moderately_active","very_active","extra_active"]),
    goal: z.enum(["weight_loss","maintenance","muscle_gain","endurance","general_health"]),
    health_conditions: z.array(z.string()).optional(),
    allergies: z.array(z.string()).optional(),
    cuisine_preferences: z.array(z.string()).optional(),
    days: z.number().min(1).max(7).default(3),
  },
  async (params) => {
    try {
      const r = await generateDietPlan(params);
      return { content: [{ type: "text", text: JSON.stringify(r, null, 2) }] };
    } catch (e) { return { content: [{ type: "text", text: String(e) }], isError: true }; }
  }
);

server.tool("log_meal",
  "Parse a natural-language meal description and log it. Returns nutritional breakdown.",
  {
    user_id: z.string(), description: z.string(),
    meal_type: z.enum(["breakfast","lunch","dinner","snack"]).optional(),
    timestamp: z.string().optional(),
  },
  async ({ user_id, description, meal_type, timestamp }) => {
    try {
      const r = await logMeal(user_id, description, meal_type, timestamp);
      return { content: [{ type: "text", text: JSON.stringify(r, null, 2) }] };
    } catch (e) { return { content: [{ type: "text", text: String(e) }], isError: true }; }
  }
);

server.tool("get_daily_summary",
  "Return nutritional totals for all logged meals on a date vs daily goals.",
  {
    user_id: z.string(), date: z.string().optional(),
    calorie_goal: z.number().optional(), protein_goal_g: z.number().optional(),
    carb_goal_g: z.number().optional(), fat_goal_g: z.number().optional(),
  },
  async ({ user_id, date, calorie_goal, protein_goal_g, carb_goal_g, fat_goal_g }) => {
    try {
      const r = await getDailySummary(user_id, date, { calories: calorie_goal, protein: protein_goal_g, carbs: carb_goal_g, fat: fat_goal_g });
      return { content: [{ type: "text", text: JSON.stringify(r, null, 2) }] };
    } catch (e) { return { content: [{ type: "text", text: String(e) }], isError: true }; }
  }
);

server.tool("analyze_meal",
  "Detailed nutritional analysis of a meal with health score and dietary flags.",
  { meal_description: z.string(), portion_notes: z.string().optional() },
  async ({ meal_description, portion_notes }) => {
    try {
      const r = await analyzeMeal(meal_description, portion_notes);
      return { content: [{ type: "text", text: JSON.stringify(r, null, 2) }] };
    } catch (e) { return { content: [{ type: "text", text: String(e) }], isError: true }; }
  }
);

server.tool("get_nutrient_recommendations",
  "Evidence-based daily RDA values adjusted for age, sex, health conditions and goal.",
  {
    age: z.number(), sex: z.enum(["male","female"]),
    health_conditions: z.array(z.string()).optional(),
    goal: z.string().optional(),
  },
  async ({ age, sex, health_conditions, goal }) => {
    try {
      const r = await getNutrientRecommendations(age, sex, health_conditions ?? [], goal);
      return { content: [{ type: "text", text: JSON.stringify(r, null, 2) }] };
    } catch (e) { return { content: [{ type: "text", text: String(e) }], isError: true }; }
  }
);

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("[nutrition-mcp] Server running on stdio.");
}
main().catch((e) => { console.error(e); process.exit(1); });

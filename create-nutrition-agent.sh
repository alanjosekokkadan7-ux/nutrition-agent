#!/usr/bin/env bash
# =============================================================================
# create-nutrition-agent.sh
# Run this script on your PC to recreate the entire NutriAgent project.
# Usage:  bash create-nutrition-agent.sh
# Requires: Node.js 20+, npm 10+
# =============================================================================
set -e

PROJECT="nutrition-agent"

echo ""
echo "=============================================="
echo "  🥗  NutriAgent — Project Generator"
echo "=============================================="
echo ""

# ── Create directory structure ─────────────────────────────────────────────
mkdir -p $PROJECT/apps/web/src/app/api/chat
mkdir -p $PROJECT/apps/web/src/app/api/food
mkdir -p $PROJECT/apps/web/src/app/api/meals
mkdir -p $PROJECT/apps/web/src/components
mkdir -p $PROJECT/apps/web/src/lib
mkdir -p $PROJECT/packages/mcp-server/src/tools
mkdir -p $PROJECT/packages/mcp-server/src/data

echo "📁 Directory structure created."

# ==============================================================================
# ROOT FILES
# ==============================================================================

cat > $PROJECT/package.json << 'ENDOFFILE'
{
  "name": "nutrition-agent",
  "version": "1.0.0",
  "private": true,
  "workspaces": ["apps/web","packages/mcp-server"],
  "scripts": {
    "dev": "npm run dev --workspace=apps/web",
    "build": "npm run build --workspace=packages/mcp-server && npm run build --workspace=apps/web",
    "mcp:build": "npm run build --workspace=packages/mcp-server"
  },
  "devDependencies": {
    "concurrently": "^8.2.2"
  }
}
ENDOFFILE

cat > $PROJECT/mcp.json << 'ENDOFFILE'
{
  "mcpServers": {
    "nutrition-agent": {
      "command": "node",
      "args": ["packages/mcp-server/build/index.js"],
      "env": { "NODE_ENV": "production" }
    }
  }
}
ENDOFFILE

cat > $PROJECT/README.md << 'ENDOFFILE'
# 🥗 NutriAgent — AI-Powered Nutrition Assistant

## Quick Start
```bash
npm install
npm run build --workspace=packages/mcp-server
cp apps/web/.env.example apps/web/.env.local
# Add your OPENAI_API_KEY to apps/web/.env.local
npm run dev --workspace=apps/web
```
Open http://localhost:3000
ENDOFFILE

# ==============================================================================
# MCP SERVER
# ==============================================================================

cat > $PROJECT/packages/mcp-server/package.json << 'ENDOFFILE'
{
  "name": "@nutrition-agent/mcp-server",
  "version": "1.0.0",
  "type": "module",
  "main": "./build/index.js",
  "bin": { "nutrition-mcp": "./build/index.js" },
  "files": ["build"],
  "scripts": {
    "build": "tsc",
    "dev": "tsc --watch"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0",
    "zod": "^3.23.8"
  },
  "devDependencies": {
    "@types/node": "^20.14.0",
    "typescript": "^5.4.5"
  }
}
ENDOFFILE

cat > $PROJECT/packages/mcp-server/tsconfig.json << 'ENDOFFILE'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "Node16",
    "moduleResolution": "Node16",
    "outDir": "./build",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules","build"]
}
ENDOFFILE

# ── MCP index.ts ──────────────────────────────────────────────────────────────
cat > $PROJECT/packages/mcp-server/src/index.ts << 'ENDOFFILE'
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
ENDOFFILE

# ── data/foodDatabase.ts ──────────────────────────────────────────────────────
cat > $PROJECT/packages/mcp-server/src/data/foodDatabase.ts << 'ENDOFFILE'
export interface Nutrition {
  calories: number; protein: number; carbs: number; fat: number; fiber: number;
  sugar: number; sodium: number; calcium: number; iron: number; vitaminC: number;
  vitaminD: number; vitaminB12: number; potassium: number; magnesium: number;
  zinc: number; cholesterol: number; saturatedFat: number; omega3: number;
}
export interface FoodEntry {
  id: string; name: string; category: string; aliases: string[];
  per100g: Nutrition; servingSize: number; servingLabel: string; tags: string[];
}
export const FOOD_DATABASE: FoodEntry[] = [
  { id:"chicken_breast_grilled", name:"Chicken Breast (Grilled)", category:"protein", aliases:["chicken breast","grilled chicken"], per100g:{calories:165,protein:31,carbs:0,fat:3.6,fiber:0,sugar:0,sodium:74,calcium:11,iron:0.9,vitaminC:0,vitaminD:0.1,vitaminB12:0.3,potassium:256,magnesium:28,zinc:1.0,cholesterol:85,saturatedFat:1.0,omega3:0.06}, servingSize:150, servingLabel:"1 breast (150g)", tags:["high-protein","low-fat","gluten-free","keto-friendly"] },
  { id:"salmon_atlantic", name:"Atlantic Salmon (Baked)", category:"protein", aliases:["salmon","baked salmon"], per100g:{calories:208,protein:20,carbs:0,fat:13,fiber:0,sugar:0,sodium:59,calcium:12,iron:0.3,vitaminC:0,vitaminD:9.4,vitaminB12:2.8,potassium:363,magnesium:27,zinc:0.6,cholesterol:63,saturatedFat:3.1,omega3:2.3}, servingSize:180, servingLabel:"1 fillet (180g)", tags:["high-protein","omega-3","heart-healthy"] },
  { id:"eggs_whole", name:"Whole Egg (Hard-Boiled)", category:"protein", aliases:["egg","eggs","boiled egg"], per100g:{calories:155,protein:13,carbs:1.1,fat:11,fiber:0,sugar:1.1,sodium:124,calcium:50,iron:1.2,vitaminC:0,vitaminD:2.0,vitaminB12:1.1,potassium:126,magnesium:10,zinc:1.1,cholesterol:373,saturatedFat:3.3,omega3:0.08}, servingSize:50, servingLabel:"1 egg (50g)", tags:["high-protein","complete-protein"] },
  { id:"tofu_firm", name:"Firm Tofu", category:"protein", aliases:["tofu","bean curd"], per100g:{calories:76,protein:8.1,carbs:1.9,fat:4.2,fiber:0.3,sugar:0.6,sodium:7,calcium:130,iron:1.5,vitaminC:0.1,vitaminD:0,vitaminB12:0,potassium:121,magnesium:30,zinc:0.8,cholesterol:0,saturatedFat:0.7,omega3:0.3}, servingSize:150, servingLabel:"½ block (150g)", tags:["vegan","plant-protein"] },
  { id:"lentils_cooked", name:"Lentils (Cooked)", category:"protein", aliases:["lentils","dal"], per100g:{calories:116,protein:9.0,carbs:20,fat:0.4,fiber:7.9,sugar:1.8,sodium:2,calcium:19,iron:3.3,vitaminC:1.5,vitaminD:0,vitaminB12:0,potassium:369,magnesium:36,zinc:1.3,cholesterol:0,saturatedFat:0.05,omega3:0.07}, servingSize:200, servingLabel:"1 cup (200g)", tags:["vegan","high-fiber","diabetic-friendly"] },
  { id:"greek_yogurt", name:"Greek Yogurt (Non-fat)", category:"dairy", aliases:["greek yogurt","yogurt","curd"], per100g:{calories:59,protein:10,carbs:3.6,fat:0.4,fiber:0,sugar:3.2,sodium:36,calcium:111,iron:0.1,vitaminC:0,vitaminD:0,vitaminB12:0.75,potassium:141,magnesium:11,zinc:0.5,cholesterol:5,saturatedFat:0.1,omega3:0}, servingSize:170, servingLabel:"1 container (170g)", tags:["high-protein","probiotic"] },
  { id:"brown_rice", name:"Brown Rice (Cooked)", category:"grain", aliases:["brown rice"], per100g:{calories:112,protein:2.3,carbs:24,fat:0.9,fiber:1.8,sugar:0.4,sodium:5,calcium:10,iron:0.5,vitaminC:0,vitaminD:0,vitaminB12:0,potassium:79,magnesium:43,zinc:0.6,cholesterol:0,saturatedFat:0.2,omega3:0.01}, servingSize:200, servingLabel:"1 cup (200g)", tags:["vegan","gluten-free","whole-grain"] },
  { id:"quinoa_cooked", name:"Quinoa (Cooked)", category:"grain", aliases:["quinoa"], per100g:{calories:120,protein:4.4,carbs:21,fat:1.9,fiber:2.8,sugar:0.9,sodium:7,calcium:17,iron:1.5,vitaminC:0,vitaminD:0,vitaminB12:0,potassium:172,magnesium:64,zinc:1.1,cholesterol:0,saturatedFat:0.2,omega3:0.09}, servingSize:185, servingLabel:"1 cup (185g)", tags:["vegan","gluten-free","complete-protein"] },
  { id:"oatmeal_cooked", name:"Oatmeal (Cooked)", category:"grain", aliases:["oatmeal","oats","porridge"], per100g:{calories:71,protein:2.5,carbs:12,fat:1.5,fiber:1.7,sugar:0,sodium:49,calcium:10,iron:0.6,vitaminC:0,vitaminD:0,vitaminB12:0,potassium:61,magnesium:17,zinc:0.5,cholesterol:0,saturatedFat:0.3,omega3:0.02}, servingSize:240, servingLabel:"1 cup (240g)", tags:["high-fiber","heart-healthy"] },
  { id:"spinach_raw", name:"Spinach (Raw)", category:"vegetable", aliases:["spinach","palak"], per100g:{calories:23,protein:2.9,carbs:3.6,fat:0.4,fiber:2.2,sugar:0.4,sodium:79,calcium:99,iron:2.7,vitaminC:28,vitaminD:0,vitaminB12:0,potassium:558,magnesium:79,zinc:0.5,cholesterol:0,saturatedFat:0.06,omega3:0.14}, servingSize:85, servingLabel:"3 cups (85g)", tags:["vegan","iron-rich","low-calorie"] },
  { id:"broccoli_steamed", name:"Broccoli (Steamed)", category:"vegetable", aliases:["broccoli"], per100g:{calories:35,protein:2.4,carbs:7.2,fat:0.4,fiber:3.3,sugar:1.7,sodium:41,calcium:47,iron:0.7,vitaminC:65,vitaminD:0,vitaminB12:0,potassium:293,magnesium:21,zinc:0.4,cholesterol:0,saturatedFat:0.04,omega3:0.1}, servingSize:148, servingLabel:"1 cup (148g)", tags:["vegan","low-calorie"] },
  { id:"sweet_potato", name:"Sweet Potato (Baked)", category:"vegetable", aliases:["sweet potato","yam"], per100g:{calories:90,protein:2.0,carbs:21,fat:0.1,fiber:3.3,sugar:6.5,sodium:36,calcium:38,iron:0.6,vitaminC:19.6,vitaminD:0,vitaminB12:0,potassium:475,magnesium:27,zinc:0.3,cholesterol:0,saturatedFat:0.02,omega3:0}, servingSize:130, servingLabel:"1 medium (130g)", tags:["vegan","gluten-free","beta-carotene"] },
  { id:"avocado", name:"Avocado", category:"fruit", aliases:["avocado"], per100g:{calories:160,protein:2.0,carbs:9.0,fat:15,fiber:6.7,sugar:0.7,sodium:7,calcium:12,iron:0.6,vitaminC:10,vitaminD:0,vitaminB12:0,potassium:485,magnesium:29,zinc:0.6,cholesterol:0,saturatedFat:2.1,omega3:0.11}, servingSize:150, servingLabel:"½ fruit (150g)", tags:["vegan","healthy-fats","keto-friendly"] },
  { id:"banana", name:"Banana", category:"fruit", aliases:["banana"], per100g:{calories:89,protein:1.1,carbs:23,fat:0.3,fiber:2.6,sugar:12,sodium:1,calcium:5,iron:0.3,vitaminC:8.7,vitaminD:0,vitaminB12:0,potassium:358,magnesium:27,zinc:0.2,cholesterol:0,saturatedFat:0.1,omega3:0.03}, servingSize:118, servingLabel:"1 medium (118g)", tags:["vegan","energy-boost"] },
  { id:"apple", name:"Apple (with skin)", category:"fruit", aliases:["apple"], per100g:{calories:52,protein:0.3,carbs:14,fat:0.2,fiber:2.4,sugar:10,sodium:1,calcium:6,iron:0.1,vitaminC:4.6,vitaminD:0,vitaminB12:0,potassium:107,magnesium:5,zinc:0.04,cholesterol:0,saturatedFat:0.03,omega3:0}, servingSize:182, servingLabel:"1 medium (182g)", tags:["vegan","antioxidant"] },
  { id:"blueberries", name:"Blueberries (Fresh)", category:"fruit", aliases:["blueberries","blueberry"], per100g:{calories:57,protein:0.7,carbs:14,fat:0.3,fiber:2.4,sugar:10,sodium:1,calcium:6,iron:0.3,vitaminC:9.7,vitaminD:0,vitaminB12:0,potassium:77,magnesium:6,zinc:0.2,cholesterol:0,saturatedFat:0.03,omega3:0.06}, servingSize:148, servingLabel:"1 cup (148g)", tags:["antioxidant","brain-health"] },
  { id:"almonds", name:"Almonds (Raw)", category:"nuts_seeds", aliases:["almonds","almond"], per100g:{calories:579,protein:21,carbs:22,fat:50,fiber:12.5,sugar:4.4,sodium:1,calcium:264,iron:3.7,vitaminC:0,vitaminD:0,vitaminB12:0,potassium:733,magnesium:270,zinc:3.1,cholesterol:0,saturatedFat:3.8,omega3:0.004}, servingSize:28, servingLabel:"1 oz (28g)", tags:["vegan","healthy-fats","heart-healthy"] },
  { id:"chia_seeds", name:"Chia Seeds", category:"nuts_seeds", aliases:["chia seeds","chia"], per100g:{calories:486,protein:17,carbs:42,fat:31,fiber:34,sugar:0,sodium:16,calcium:631,iron:7.7,vitaminC:1.6,vitaminD:0,vitaminB12:0,potassium:407,magnesium:335,zinc:4.6,cholesterol:0,saturatedFat:3.3,omega3:17.5}, servingSize:28, servingLabel:"2 tbsp (28g)", tags:["vegan","omega-3","high-fiber"] },
  { id:"chickpeas_cooked", name:"Chickpeas (Cooked)", category:"legume", aliases:["chickpeas","chana","garbanzo"], per100g:{calories:164,protein:8.9,carbs:27,fat:2.6,fiber:7.6,sugar:4.8,sodium:7,calcium:49,iron:2.9,vitaminC:1.3,vitaminD:0,vitaminB12:0,potassium:291,magnesium:48,zinc:1.5,cholesterol:0,saturatedFat:0.3,omega3:0.04}, servingSize:164, servingLabel:"1 cup (164g)", tags:["vegan","high-fiber","plant-protein"] },
  { id:"milk_whole", name:"Whole Milk", category:"dairy", aliases:["milk","whole milk"], per100g:{calories:61,protein:3.2,carbs:4.8,fat:3.3,fiber:0,sugar:5.1,sodium:43,calcium:113,iron:0.03,vitaminC:0.9,vitaminD:0.1,vitaminB12:0.45,potassium:132,magnesium:10,zinc:0.4,cholesterol:10,saturatedFat:1.9,omega3:0.07}, servingSize:244, servingLabel:"1 cup (244ml)", tags:["vegetarian","calcium-rich"] },
  { id:"olive_oil", name:"Olive Oil (EVOO)", category:"fat", aliases:["olive oil","extra virgin olive oil"], per100g:{calories:884,protein:0,carbs:0,fat:100,fiber:0,sugar:0,sodium:2,calcium:1,iron:0.6,vitaminC:0,vitaminD:0,vitaminB12:0,potassium:1,magnesium:0,zinc:0,cholesterol:0,saturatedFat:13.8,omega3:0.76}, servingSize:14, servingLabel:"1 tbsp (14g)", tags:["vegan","heart-healthy","mediterranean"] },
];

function tokenize(t: string): string[] {
  return t.toLowerCase().replace(/[^a-z0-9\s]/g,"").split(/\s+/).filter(Boolean);
}
export function searchFoods(query: string, topK = 3): FoodEntry[] {
  const tokens = tokenize(query);
  return FOOD_DATABASE.map(f => {
    const haystack = tokenize(f.name+" "+f.aliases.join(" ")+" "+f.tags.join(" "));
    const score = tokens.filter(t => haystack.includes(t)).length;
    return { f, score };
  }).filter(x => x.score > 0).sort((a,b) => b.score-a.score).slice(0,topK).map(x => x.f);
}
export function scaleNutrition(n: Nutrition, g: number): Nutrition {
  const f = g/100;
  const r = (v: number, dp=1) => Math.round(v*f*10**dp)/10**dp;
  return { calories:r(n.calories), protein:r(n.protein), carbs:r(n.carbs), fat:r(n.fat), fiber:r(n.fiber), sugar:r(n.sugar), sodium:r(n.sodium,0), calcium:r(n.calcium,0), iron:r(n.iron,2), vitaminC:r(n.vitaminC), vitaminD:r(n.vitaminD,2), vitaminB12:r(n.vitaminB12,2), potassium:r(n.potassium,0), magnesium:r(n.magnesium,0), zinc:r(n.zinc,2), cholesterol:r(n.cholesterol,0), saturatedFat:r(n.saturatedFat), omega3:r(n.omega3,2) };
}
ENDOFFILE

# ── data/mealStore.ts ─────────────────────────────────────────────────────────
cat > $PROJECT/packages/mcp-server/src/data/mealStore.ts << 'ENDOFFILE'
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
ENDOFFILE

# ── tools/searchFoodNutrition.ts ──────────────────────────────────────────────
cat > $PROJECT/packages/mcp-server/src/tools/searchFoodNutrition.ts << 'ENDOFFILE'
import { searchFoods, scaleNutrition } from "../data/foodDatabase.js";
export async function searchFoodNutrition(query: string, servingGrams: number) {
  const results = searchFoods(query, 5);
  if (results.length === 0) return { query, message: "No results found.", results: [] };
  return { query, servingGrams, results: results.map(food => ({ name: food.name, category: food.category, source: "USDA FoodData Central", per100g: food.per100g, perServing: { grams: servingGrams, ...scaleNutrition(food.per100g, servingGrams) }, tags: food.tags })) };
}
ENDOFFILE

# ── tools/generateDietPlan.ts ─────────────────────────────────────────────────
cat > $PROJECT/packages/mcp-server/src/tools/generateDietPlan.ts << 'ENDOFFILE'
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
ENDOFFILE

# ── tools/logMeal.ts ──────────────────────────────────────────────────────────
cat > $PROJECT/packages/mcp-server/src/tools/logMeal.ts << 'ENDOFFILE'
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
ENDOFFILE

# ── tools/getDailySummary.ts ──────────────────────────────────────────────────
cat > $PROJECT/packages/mcp-server/src/tools/getDailySummary.ts << 'ENDOFFILE'
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
ENDOFFILE

# ── tools/analyzeMeal.ts ──────────────────────────────────────────────────────
cat > $PROJECT/packages/mcp-server/src/tools/analyzeMeal.ts << 'ENDOFFILE'
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
ENDOFFILE

# ── tools/getNutrientRecommendations.ts ───────────────────────────────────────
cat > $PROJECT/packages/mcp-server/src/tools/getNutrientRecommendations.ts << 'ENDOFFILE'
export async function getNutrientRecommendations(age: number, sex: "male"|"female", healthConditions: string[], goal?: string) {
  const isMale=sex==="male", isSenior=age>50;
  const p = { calories:isMale?(isSenior?2200:2500):(isSenior?1800:2000), protein_g:isMale?56:46, fat_g:isMale?78:62, carbs_g:isMale?325:260, fiber_g:isMale?38:25, calcium_mg:isSenior?1200:1000, iron_mg:isMale?8:(age>=19&&age<=50?18:8), vitaminC_mg:isMale?90:75, vitaminD_mcg:isSenior?20:15, vitaminB12_mcg:2.4, sodium_mg:2300, notes:[] as string[] };
  const c = healthConditions.map(x=>x.toLowerCase());
  if(c.includes("pregnancy")){p.iron_mg=27;p.calories+=340;p.notes.push("Folic acid 600µg/day essential");}
  if(c.includes("type2_diabetes")||c.includes("diabetes")){p.carbs_g=Math.round(p.carbs_g*0.85);p.notes.push("Prefer low-GI carbs; limit refined sugar");}
  if(c.includes("hypertension")){p.sodium_mg=1500;p.notes.push("Follow DASH diet; limit sodium to 1500mg");}
  if(c.includes("osteoporosis")){p.calcium_mg=1200;p.vitaminD_mcg=20;}
  if(goal?.includes("muscle_gain")){p.protein_g=Math.round(p.calories*0.30/4);p.calories+=300;}
  if(goal?.includes("weight_loss")){p.calories=Math.round(p.calories*0.8);p.protein_g=Math.round(p.protein_g*1.2);}
  return { age, sex, healthConditions, goal:goal??"general_health", dailyRecommendations:p, source:"DRI — National Academies (2020)" };
}
ENDOFFILE

echo "✅ MCP server files written."

# ==============================================================================
# WEB APP
# ==============================================================================

cat > $PROJECT/apps/web/package.json << 'ENDOFFILE'
{
  "name": "@nutrition-agent/web",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "14.2.5",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "openai": "^4.56.0",
    "clsx": "^2.1.1"
  },
  "devDependencies": {
    "@types/node": "^20.14.0",
    "@types/react": "^18.3.3",
    "@types/react-dom": "^18.3.0",
    "typescript": "^5.4.5",
    "tailwindcss": "^3.4.9",
    "postcss": "^8.4.40",
    "autoprefixer": "^10.4.20",
    "eslint": "^8.57.0",
    "eslint-config-next": "14.2.5"
  }
}
ENDOFFILE

cat > $PROJECT/apps/web/tsconfig.json << 'ENDOFFILE'
{
  "compilerOptions": {
    "lib": ["dom","dom.iterable","esnext"],
    "allowJs": true, "skipLibCheck": true, "strict": true, "noEmit": true,
    "esModuleInterop": true, "module": "esnext", "moduleResolution": "bundler",
    "resolveJsonModule": true, "isolatedModules": true, "jsx": "preserve", "incremental": true,
    "plugins": [{ "name": "next" }], "paths": { "@/*": ["./src/*"] }
  },
  "include": ["next-env.d.ts","**/*.ts","**/*.tsx",".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
ENDOFFILE

cat > $PROJECT/apps/web/tailwind.config.js << 'ENDOFFILE'
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./src/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: {
    extend: {
      colors: {
        brand: { 50:"#f0fdf4",100:"#dcfce7",200:"#bbf7d0",500:"#22c55e",600:"#16a34a",700:"#15803d",900:"#14532d" }
      }
    }
  },
  plugins: []
};
ENDOFFILE

cat > $PROJECT/apps/web/postcss.config.js << 'ENDOFFILE'
module.exports = { plugins: { tailwindcss: {}, autoprefixer: {} } };
ENDOFFILE

cat > $PROJECT/apps/web/next.config.ts << 'ENDOFFILE'
import type { NextConfig } from "next";
const nextConfig: NextConfig = {};
export default nextConfig;
ENDOFFILE

cat > $PROJECT/apps/web/.env.example << 'ENDOFFILE'
# Required
OPENAI_API_KEY=sk-...your-key-here...

# Optional
# OPENAI_MODEL=gpt-4o-mini
# OPENAI_BASE_URL=http://localhost:11434/v1
ENDOFFILE

cat > $PROJECT/apps/web/src/app/globals.css << 'ENDOFFILE'
@tailwind base;
@tailwind components;
@tailwind utilities;
.bubble-user { @apply bg-green-600 text-white rounded-2xl rounded-br-sm px-4 py-2 max-w-[80%] self-end text-sm; }
.bubble-ai   { @apply bg-white border border-gray-200 rounded-2xl rounded-bl-sm px-4 py-2 max-w-[85%] self-start text-sm shadow-sm; }
.card        { @apply bg-white rounded-2xl shadow-sm border border-gray-100 p-5; }
.macro-bar   { @apply h-2 rounded-full bg-gray-200 overflow-hidden; }
.macro-bar-fill { @apply h-full rounded-full transition-all duration-500; }
ENDOFFILE

cat > $PROJECT/apps/web/src/app/layout.tsx << 'ENDOFFILE'
import type { Metadata } from "next";
import "./globals.css";
export const metadata: Metadata = { title: "NutriAgent — AI Nutrition Assistant", description: "Personalized diet plans, food lookup, and meal tracking." };
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return <html lang="en"><body className="bg-gray-50 text-gray-900 antialiased">{children}</body></html>;
}
ENDOFFILE

# ── page.tsx ──────────────────────────────────────────────────────────────────
cat > $PROJECT/apps/web/src/app/page.tsx << 'ENDOFFILE'
"use client";
import { useState } from "react";
import ChatPanel from "@/components/ChatPanel";
import DietTracker from "@/components/DietTracker";
import MealLogger from "@/components/MealLogger";
import FoodSearch from "@/components/FoodSearch";
import DietPlanWizard from "@/components/DietPlanWizard";

type Tab = "chat"|"tracker"|"log"|"search"|"plan";
const TABS: { id: Tab; label: string; icon: string }[] = [
  {id:"chat",label:"AI Chat",icon:"💬"},{id:"tracker",label:"Daily Tracker",icon:"📊"},
  {id:"log",label:"Log Meal",icon:"🍽️"},{id:"search",label:"Food Search",icon:"🔍"},
  {id:"plan",label:"Diet Plan",icon:"📋"},
];
export default function HomePage() {
  const [tab, setTab] = useState<Tab>("chat");
  return (
    <div className="min-h-screen flex flex-col">
      <header className="bg-white border-b border-gray-200 sticky top-0 z-10">
        <div className="max-w-4xl mx-auto px-4 py-3 flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl bg-green-600 flex items-center justify-center text-white font-bold">N</div>
          <div><h1 className="text-base font-semibold">NutriAgent</h1><p className="text-xs text-gray-500">AI-Powered Nutrition Assistant</p></div>
          <span className="ml-auto text-xs bg-green-100 text-green-700 px-2 py-0.5 rounded-full">Powered by GPT-4o</span>
        </div>
        <div className="max-w-4xl mx-auto px-4 flex gap-1 overflow-x-auto">
          {TABS.map(t => (
            <button key={t.id} onClick={() => setTab(t.id)}
              className={`px-4 py-2 text-sm font-medium rounded-t-lg whitespace-nowrap transition-colors ${tab===t.id?"bg-green-50 text-green-700 border-t border-x border-gray-200":"text-gray-500 hover:text-gray-700"}`}>
              {t.icon} {t.label}
            </button>
          ))}
        </div>
      </header>
      <main className="flex-1 max-w-4xl mx-auto w-full px-4 py-6">
        {tab==="chat"    && <ChatPanel />}
        {tab==="tracker" && <DietTracker />}
        {tab==="log"     && <MealLogger />}
        {tab==="search"  && <FoodSearch />}
        {tab==="plan"    && <DietPlanWizard />}
      </main>
      <footer className="text-center text-xs text-gray-400 py-4 border-t border-gray-100">
        NutriAgent — For informational purposes only. Consult a registered dietitian for medical advice.
      </footer>
    </div>
  );
}
ENDOFFILE

echo "✅ Web app shell written."

# ── API routes ────────────────────────────────────────────────────────────────
cat > $PROJECT/apps/web/src/app/api/chat/route.ts << 'ENDOFFILE'
import { NextRequest, NextResponse } from "next/server";
import OpenAI from "openai";
import { searchFoods, scaleNutrition } from "@/lib/foodDatabase";

const client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY ?? "", baseURL: process.env.OPENAI_BASE_URL });
const MODEL = process.env.OPENAI_MODEL ?? "gpt-4o";

const TOOLS: OpenAI.Chat.ChatCompletionTool[] = [
  { type:"function", function:{ name:"search_food_nutrition", description:"Search nutritional values of a food from the knowledge base.", parameters:{ type:"object", properties:{ query:{type:"string"}, serving_grams:{type:"number"} }, required:["query"] } } },
  { type:"function", function:{ name:"analyze_meal", description:"Analyze nutritional content of a described meal.", parameters:{ type:"object", properties:{ meal_description:{type:"string"}, portion_notes:{type:"string"} }, required:["meal_description"] } } },
  { type:"function", function:{ name:"get_nutrient_recommendations", description:"Get daily RDA for a user profile.", parameters:{ type:"object", properties:{ age:{type:"number"}, sex:{type:"string",enum:["male","female"]}, health_conditions:{type:"array",items:{type:"string"}}, goal:{type:"string"} }, required:["age","sex"] } } },
];

async function executeTool(name: string, args: Record<string,unknown>): Promise<string> {
  if (name === "search_food_nutrition") {
    const r = searchFoods(String(args.query??""), 3);
    if (r.length===0) return JSON.stringify({ message:"No results found" });
    return JSON.stringify(r.map(f => ({ name:f.name, per100g:f.per100g, perServing:{ grams:Number(args.serving_grams??100), ...scaleNutrition(f.per100g, Number(args.serving_grams??100)) }, tags:f.tags })));
  }
  if (name === "analyze_meal") {
    const { analyzeMeal } = await import("@/lib/analyzeMeal");
    return JSON.stringify(await analyzeMeal(String(args.meal_description), args.portion_notes as string|undefined));
  }
  if (name === "get_nutrient_recommendations") {
    const { getNutrientRecommendations } = await import("@/lib/recommendations");
    return JSON.stringify(await getNutrientRecommendations(Number(args.age), String(args.sex) as "male"|"female", (args.health_conditions as string[])??[], args.goal as string|undefined));
  }
  return JSON.stringify({ error:`Unknown tool: ${name}` });
}

const SYSTEM = `You are NutriAgent, an expert AI nutrition assistant. Help users with dietary advice, food nutrition data, meal analysis, and daily nutrient recommendations. Always use tools to retrieve accurate data. Be warm, specific, and evidence-based. Add a disclaimer when giving advice for medical conditions.`;

export async function POST(req: NextRequest) {
  try {
    const { messages } = await req.json() as { messages: OpenAI.Chat.ChatCompletionMessageParam[] };
    const all: OpenAI.Chat.ChatCompletionMessageParam[] = [{ role:"system", content:SYSTEM }, ...messages];
    for (let i=0; i<5; i++) {
      const resp = await client.chat.completions.create({ model:MODEL, messages:all, tools:TOOLS, tool_choice:"auto", max_tokens:1500 });
      const choice = resp.choices[0];
      all.push(choice.message);
      if (choice.finish_reason==="stop"||choice.finish_reason==="length") return NextResponse.json({ reply: choice.message.content??""});
      if (choice.finish_reason==="tool_calls" && choice.message.tool_calls) {
        for (const tc of choice.message.tool_calls) {
          const result = await executeTool(tc.function.name, JSON.parse(tc.function.arguments) as Record<string,unknown>);
          all.push({ role:"tool", tool_call_id:tc.id, content:result });
        }
      } else return NextResponse.json({ reply: choice.message.content??"" });
    }
    return NextResponse.json({ reply: "Processing limit reached. Please try a more specific question." });
  } catch (e) {
    return NextResponse.json({ error: String(e) }, { status:500 });
  }
}
ENDOFFILE

cat > $PROJECT/apps/web/src/app/api/food/route.ts << 'ENDOFFILE'
import { NextRequest, NextResponse } from "next/server";
import { searchFoods, scaleNutrition } from "@/lib/foodDatabase";
export async function GET(req: NextRequest) {
  const q = req.nextUrl.searchParams.get("q")??"";
  const g = parseInt(req.nextUrl.searchParams.get("g")??"100");
  if (!q.trim()) return NextResponse.json({ results:[] });
  return NextResponse.json({ results: searchFoods(q, 5).map(f => ({ id:f.id, name:f.name, category:f.category, per100g:f.per100g, perServing:{grams:g,...scaleNutrition(f.per100g,g)}, tags:f.tags })) });
}
ENDOFFILE

cat > $PROJECT/apps/web/src/app/api/meals/route.ts << 'ENDOFFILE'
import { NextRequest, NextResponse } from "next/server";
import { logMealFromText, getDailySummary } from "@/lib/mealStore";
export async function POST(req: NextRequest) {
  try {
    const b = await req.json() as { userId:string; description:string; mealType?:"breakfast"|"lunch"|"dinner"|"snack" };
    return NextResponse.json(logMealFromText(b.userId, b.description, b.mealType));
  } catch(e) { return NextResponse.json({ error:String(e) }, { status:400 }); }
}
export async function GET(req: NextRequest) {
  const userId = req.nextUrl.searchParams.get("userId")??"default";
  const date = req.nextUrl.searchParams.get("date")??undefined;
  return NextResponse.json(getDailySummary(userId, date));
}
ENDOFFILE

echo "✅ API routes written."

# ── lib files ─────────────────────────────────────────────────────────────────
cat > $PROJECT/apps/web/src/lib/foodDatabase.ts << 'ENDOFFILE'
export interface Nutrition { calories:number;protein:number;carbs:number;fat:number;fiber:number;sugar:number;sodium:number;calcium:number;iron:number;vitaminC:number;vitaminD:number;vitaminB12:number;potassium:number;magnesium:number;zinc:number;cholesterol:number;saturatedFat:number;omega3:number; }
export interface FoodEntry { id:string;name:string;category:string;aliases:string[];per100g:Nutrition;servingSize:number;servingLabel:string;tags:string[]; }
export const FOOD_DATABASE: FoodEntry[] = [
  {id:"chicken_breast_grilled",name:"Chicken Breast (Grilled)",category:"protein",aliases:["chicken breast","grilled chicken"],per100g:{calories:165,protein:31,carbs:0,fat:3.6,fiber:0,sugar:0,sodium:74,calcium:11,iron:0.9,vitaminC:0,vitaminD:0.1,vitaminB12:0.3,potassium:256,magnesium:28,zinc:1.0,cholesterol:85,saturatedFat:1.0,omega3:0.06},servingSize:150,servingLabel:"1 breast (150g)",tags:["high-protein","low-fat","gluten-free"]},
  {id:"salmon_atlantic",name:"Atlantic Salmon (Baked)",category:"protein",aliases:["salmon","baked salmon"],per100g:{calories:208,protein:20,carbs:0,fat:13,fiber:0,sugar:0,sodium:59,calcium:12,iron:0.3,vitaminC:0,vitaminD:9.4,vitaminB12:2.8,potassium:363,magnesium:27,zinc:0.6,cholesterol:63,saturatedFat:3.1,omega3:2.3},servingSize:180,servingLabel:"1 fillet (180g)",tags:["high-protein","omega-3","heart-healthy"]},
  {id:"eggs_whole",name:"Whole Egg (Hard-Boiled)",category:"protein",aliases:["egg","eggs","boiled egg"],per100g:{calories:155,protein:13,carbs:1.1,fat:11,fiber:0,sugar:1.1,sodium:124,calcium:50,iron:1.2,vitaminC:0,vitaminD:2.0,vitaminB12:1.1,potassium:126,magnesium:10,zinc:1.1,cholesterol:373,saturatedFat:3.3,omega3:0.08},servingSize:50,servingLabel:"1 egg (50g)",tags:["high-protein","complete-protein"]},
  {id:"tofu_firm",name:"Firm Tofu",category:"protein",aliases:["tofu","bean curd"],per100g:{calories:76,protein:8.1,carbs:1.9,fat:4.2,fiber:0.3,sugar:0.6,sodium:7,calcium:130,iron:1.5,vitaminC:0.1,vitaminD:0,vitaminB12:0,potassium:121,magnesium:30,zinc:0.8,cholesterol:0,saturatedFat:0.7,omega3:0.3},servingSize:150,servingLabel:"½ block (150g)",tags:["vegan","plant-protein"]},
  {id:"lentils_cooked",name:"Lentils (Cooked)",category:"protein",aliases:["lentils","dal"],per100g:{calories:116,protein:9.0,carbs:20,fat:0.4,fiber:7.9,sugar:1.8,sodium:2,calcium:19,iron:3.3,vitaminC:1.5,vitaminD:0,vitaminB12:0,potassium:369,magnesium:36,zinc:1.3,cholesterol:0,saturatedFat:0.05,omega3:0.07},servingSize:200,servingLabel:"1 cup (200g)",tags:["vegan","high-fiber","diabetic-friendly"]},
  {id:"greek_yogurt",name:"Greek Yogurt (Non-fat)",category:"dairy",aliases:["greek yogurt","yogurt","curd"],per100g:{calories:59,protein:10,carbs:3.6,fat:0.4,fiber:0,sugar:3.2,sodium:36,calcium:111,iron:0.1,vitaminC:0,vitaminD:0,vitaminB12:0.75,potassium:141,magnesium:11,zinc:0.5,cholesterol:5,saturatedFat:0.1,omega3:0},servingSize:170,servingLabel:"1 container (170g)",tags:["high-protein","probiotic"]},
  {id:"brown_rice",name:"Brown Rice (Cooked)",category:"grain",aliases:["brown rice"],per100g:{calories:112,protein:2.3,carbs:24,fat:0.9,fiber:1.8,sugar:0.4,sodium:5,calcium:10,iron:0.5,vitaminC:0,vitaminD:0,vitaminB12:0,potassium:79,magnesium:43,zinc:0.6,cholesterol:0,saturatedFat:0.2,omega3:0.01},servingSize:200,servingLabel:"1 cup (200g)",tags:["vegan","gluten-free","whole-grain"]},
  {id:"quinoa_cooked",name:"Quinoa (Cooked)",category:"grain",aliases:["quinoa"],per100g:{calories:120,protein:4.4,carbs:21,fat:1.9,fiber:2.8,sugar:0.9,sodium:7,calcium:17,iron:1.5,vitaminC:0,vitaminD:0,vitaminB12:0,potassium:172,magnesium:64,zinc:1.1,cholesterol:0,saturatedFat:0.2,omega3:0.09},servingSize:185,servingLabel:"1 cup (185g)",tags:["vegan","gluten-free","complete-protein"]},
  {id:"oatmeal_cooked",name:"Oatmeal (Cooked)",category:"grain",aliases:["oatmeal","oats","porridge"],per100g:{calories:71,protein:2.5,carbs:12,fat:1.5,fiber:1.7,sugar:0,sodium:49,calcium:10,iron:0.6,vitaminC:0,vitaminD:0,vitaminB12:0,potassium:61,magnesium:17,zinc:0.5,cholesterol:0,saturatedFat:0.3,omega3:0.02},servingSize:240,servingLabel:"1 cup (240g)",tags:["high-fiber","heart-healthy"]},
  {id:"spinach_raw",name:"Spinach (Raw)",category:"vegetable",aliases:["spinach","palak"],per100g:{calories:23,protein:2.9,carbs:3.6,fat:0.4,fiber:2.2,sugar:0.4,sodium:79,calcium:99,iron:2.7,vitaminC:28,vitaminD:0,vitaminB12:0,potassium:558,magnesium:79,zinc:0.5,cholesterol:0,saturatedFat:0.06,omega3:0.14},servingSize:85,servingLabel:"3 cups (85g)",tags:["vegan","iron-rich","low-calorie"]},
  {id:"broccoli_steamed",name:"Broccoli (Steamed)",category:"vegetable",aliases:["broccoli"],per100g:{calories:35,protein:2.4,carbs:7.2,fat:0.4,fiber:3.3,sugar:1.7,sodium:41,calcium:47,iron:0.7,vitaminC:65,vitaminD:0,vitaminB12:0,potassium:293,magnesium:21,zinc:0.4,cholesterol:0,saturatedFat:0.04,omega3:0.1},servingSize:148,servingLabel:"1 cup (148g)",tags:["vegan","low-calorie"]},
  {id:"sweet_potato",name:"Sweet Potato (Baked)",category:"vegetable",aliases:["sweet potato","yam"],per100g:{calories:90,protein:2.0,carbs:21,fat:0.1,fiber:3.3,sugar:6.5,sodium:36,calcium:38,iron:0.6,vitaminC:19.6,vitaminD:0,vitaminB12:0,potassium:475,magnesium:27,zinc:0.3,cholesterol:0,saturatedFat:0.02,omega3:0},servingSize:130,servingLabel:"1 medium (130g)",tags:["vegan","gluten-free","beta-carotene"]},
  {id:"avocado",name:"Avocado",category:"fruit",aliases:["avocado"],per100g:{calories:160,protein:2.0,carbs:9.0,fat:15,fiber:6.7,sugar:0.7,sodium:7,calcium:12,iron:0.6,vitaminC:10,vitaminD:0,vitaminB12:0,potassium:485,magnesium:29,zinc:0.6,cholesterol:0,saturatedFat:2.1,omega3:0.11},servingSize:150,servingLabel:"½ fruit (150g)",tags:["vegan","healthy-fats","keto-friendly"]},
  {id:"banana",name:"Banana",category:"fruit",aliases:["banana"],per100g:{calories:89,protein:1.1,carbs:23,fat:0.3,fiber:2.6,sugar:12,sodium:1,calcium:5,iron:0.3,vitaminC:8.7,vitaminD:0,vitaminB12:0,potassium:358,magnesium:27,zinc:0.2,cholesterol:0,saturatedFat:0.1,omega3:0.03},servingSize:118,servingLabel:"1 medium (118g)",tags:["vegan","energy-boost"]},
  {id:"apple",name:"Apple (with skin)",category:"fruit",aliases:["apple"],per100g:{calories:52,protein:0.3,carbs:14,fat:0.2,fiber:2.4,sugar:10,sodium:1,calcium:6,iron:0.1,vitaminC:4.6,vitaminD:0,vitaminB12:0,potassium:107,magnesium:5,zinc:0.04,cholesterol:0,saturatedFat:0.03,omega3:0},servingSize:182,servingLabel:"1 medium (182g)",tags:["vegan","antioxidant"]},
  {id:"almonds",name:"Almonds (Raw)",category:"nuts_seeds",aliases:["almonds","almond"],per100g:{calories:579,protein:21,carbs:22,fat:50,fiber:12.5,sugar:4.4,sodium:1,calcium:264,iron:3.7,vitaminC:0,vitaminD:0,vitaminB12:0,potassium:733,magnesium:270,zinc:3.1,cholesterol:0,saturatedFat:3.8,omega3:0.004},servingSize:28,servingLabel:"1 oz (28g)",tags:["vegan","healthy-fats","heart-healthy"]},
  {id:"chickpeas_cooked",name:"Chickpeas (Cooked)",category:"legume",aliases:["chickpeas","chana","garbanzo"],per100g:{calories:164,protein:8.9,carbs:27,fat:2.6,fiber:7.6,sugar:4.8,sodium:7,calcium:49,iron:2.9,vitaminC:1.3,vitaminD:0,vitaminB12:0,potassium:291,magnesium:48,zinc:1.5,cholesterol:0,saturatedFat:0.3,omega3:0.04},servingSize:164,servingLabel:"1 cup (164g)",tags:["vegan","high-fiber","plant-protein"]},
  {id:"olive_oil",name:"Olive Oil (EVOO)",category:"fat",aliases:["olive oil","extra virgin olive oil"],per100g:{calories:884,protein:0,carbs:0,fat:100,fiber:0,sugar:0,sodium:2,calcium:1,iron:0.6,vitaminC:0,vitaminD:0,vitaminB12:0,potassium:1,magnesium:0,zinc:0,cholesterol:0,saturatedFat:13.8,omega3:0.76},servingSize:14,servingLabel:"1 tbsp (14g)",tags:["vegan","heart-healthy","mediterranean"]},
];
function tokenize(t: string): string[] { return t.toLowerCase().replace(/[^a-z0-9\s]/g,"").split(/\s+/).filter(Boolean); }
export function searchFoods(query: string, topK=3): FoodEntry[] {
  const tokens = tokenize(query);
  return FOOD_DATABASE.map(f => ({ f, score: tokens.filter(t => tokenize(f.name+" "+f.aliases.join(" ")+" "+f.tags.join(" ")).includes(t)).length }))
    .filter(x=>x.score>0).sort((a,b)=>b.score-a.score).slice(0,topK).map(x=>x.f);
}
export function scaleNutrition(n: Nutrition, g: number): Nutrition {
  const f=g/100, r=(v:number,dp=1)=>Math.round(v*f*10**dp)/10**dp;
  return {calories:r(n.calories),protein:r(n.protein),carbs:r(n.carbs),fat:r(n.fat),fiber:r(n.fiber),sugar:r(n.sugar),sodium:r(n.sodium,0),calcium:r(n.calcium,0),iron:r(n.iron,2),vitaminC:r(n.vitaminC),vitaminD:r(n.vitaminD,2),vitaminB12:r(n.vitaminB12,2),potassium:r(n.potassium,0),magnesium:r(n.magnesium,0),zinc:r(n.zinc,2),cholesterol:r(n.cholesterol,0),saturatedFat:r(n.saturatedFat),omega3:r(n.omega3,2)};
}
ENDOFFILE

cat > $PROJECT/apps/web/src/lib/mealStore.ts << 'ENDOFFILE'
import { searchFoods, scaleNutrition, type Nutrition } from "./foodDatabase";
export interface MealLogEntry { id:string;userId:string;timestamp:string;mealType:"breakfast"|"lunch"|"dinner"|"snack";description:string;items:Array<{name:string;grams:number;calories:number;protein:number;carbs:number;fat:number}>;totals:{calories:number;protein:number;carbs:number;fat:number;fiber:number;sodium:number}; }
const STORE_KEY="nutriagent_meals";
function loadStore(): Map<string,MealLogEntry[]> {
  if(typeof window==="undefined") return new Map();
  try { const r=sessionStorage.getItem(STORE_KEY); return r?new Map(Object.entries(JSON.parse(r) as Record<string,MealLogEntry[]>)):new Map(); } catch { return new Map(); }
}
function saveStore(s: Map<string,MealLogEntry[]>) { if(typeof window!=="undefined") sessionStorage.setItem(STORE_KEY,JSON.stringify(Object.fromEntries(s.entries()))); }
function makeId() { return Date.now().toString(36)+Math.random().toString(36).slice(2,6); }
function inferType(ts: string): "breakfast"|"lunch"|"dinner"|"snack" { const h=new Date(ts).getHours(); if(h>=5&&h<11)return"breakfast"; if(h>=11&&h<15)return"lunch"; if(h>=15&&h<18)return"snack"; return"dinner"; }
export function logMealFromText(userId: string, description: string, mealType?: "breakfast"|"lunch"|"dinner"|"snack") {
  const ts=new Date().toISOString(), type=mealType??inferType(ts);
  const segs=description.split(/\band\b|,|with|plus/i).map(s=>s.trim()).filter(Boolean);
  const items: MealLogEntry["items"]=[];
  for(const seg of segs) {
    const nm=seg.match(/^(\d+(?:\.\d+)?)\s*(g|grams?)?\s+(.+)/i);
    const grams=nm?(/g|gram/i.test(nm[2]??"")?parseFloat(nm[1]):parseFloat(nm[1])*150):150;
    const raw=nm?nm[3]:seg;
    const m=searchFoods(raw,1)[0];
    if(m){const n=scaleNutrition(m.per100g,grams);items.push({name:m.name,grams,calories:n.calories,protein:n.protein,carbs:n.carbs,fat:n.fat});}
  }
  const totals=items.reduce((a,i)=>({calories:a.calories+i.calories,protein:a.protein+i.protein,carbs:a.carbs+i.carbs,fat:a.fat+i.fat,fiber:a.fiber,sodium:a.sodium}),{calories:0,protein:0,carbs:0,fat:0,fiber:0,sodium:0});
  const entry:MealLogEntry={id:makeId(),userId,timestamp:ts,mealType:type,description,items,totals};
  const s=loadStore(); const dk=`${userId}_${ts.slice(0,10)}`; if(!s.has(dk))s.set(dk,[]); s.get(dk)!.push(entry); saveStore(s);
  const flags:string[]=[]; if(totals.calories>900)flags.push("ℹ Calorie-dense"); if(totals.protein<10&&items.length>1)flags.push("ℹ Low protein");
  return {entry,flags};
}
export function getDailySummary(userId: string, date?: string, goals:{calories?:number;protein?:number}={}) {
  const dk=date??new Date().toISOString().slice(0,10), s=loadStore();
  const entries=s.get(`${userId}_${dk}`)??[];
  const totals=entries.reduce((a,e)=>({calories:a.calories+e.totals.calories,protein:a.protein+e.totals.protein,carbs:a.carbs+e.totals.carbs,fat:a.fat+e.totals.fat}),{calories:0,protein:0,carbs:0,fat:0});
  const cg=goals.calories??2000,pg=goals.protein??50;
  const insights:string[]=[]; if(totals.calories>cg*1.1)insights.push("⚠ Exceeded calorie goal"); if(totals.protein<pg*0.6)insights.push("ℹ Protein intake is low"); if(entries.length===0)insights.push("No meals logged today yet.");
  return {date:dk,entries,totals,goals:{calories:cg,protein:pg},insights};
}
export function getAllEntries(userId: string): MealLogEntry[] {
  const s=loadStore(); const r:MealLogEntry[]=[];
  for(const[k,v]of s.entries())if(k.startsWith(userId+"_"))r.push(...v);
  return r.sort((a,b)=>b.timestamp.localeCompare(a.timestamp));
}
ENDOFFILE

cat > $PROJECT/apps/web/src/lib/recommendations.ts << 'ENDOFFILE'
export async function getNutrientRecommendations(age:number,sex:"male"|"female",healthConditions:string[]=[],goal?:string){
  const isMale=sex==="male",isSenior=age>50;
  const p={calories:isMale?(isSenior?2200:2500):(isSenior?1800:2000),protein_g:isMale?56:46,fat_g:isMale?78:62,carbs_g:isMale?325:260,fiber_g:isMale?38:25,calcium_mg:isSenior?1200:1000,iron_mg:isMale?8:(age>=19&&age<=50?18:8),vitaminC_mg:isMale?90:75,vitaminD_mcg:isSenior?20:15,vitaminB12_mcg:2.4,sodium_mg:2300,notes:[] as string[]};
  const c=healthConditions.map(x=>x.toLowerCase());
  if(c.includes("pregnancy")){p.iron_mg=27;p.calories+=340;p.notes.push("Folic acid 600µg/day essential");}
  if(c.includes("type2_diabetes")||c.includes("diabetes")){p.carbs_g=Math.round(p.carbs_g*0.85);p.notes.push("Prefer low-GI carbs; limit refined sugar");}
  if(c.includes("hypertension")){p.sodium_mg=1500;p.notes.push("Follow DASH diet; limit sodium to 1500mg");}
  if(goal?.includes("muscle_gain")){p.protein_g=Math.round(p.calories*0.30/4);p.calories+=300;}
  if(goal?.includes("weight_loss")){p.calories=Math.round(p.calories*0.8);p.protein_g=Math.round(p.protein_g*1.2);}
  return {age,sex,healthConditions,goal:goal??"general_health",dailyRecommendations:p};
}
ENDOFFILE

cat > $PROJECT/apps/web/src/lib/analyzeMeal.ts << 'ENDOFFILE'
import { searchFoods, scaleNutrition, type Nutrition } from "./foodDatabase";
export async function analyzeMeal(desc:string,portionNotes?:string){
  const full=portionNotes?`${desc} ${portionNotes}`:desc;
  const segs=full.split(/,|with|and/i).map(s=>s.trim()).filter(Boolean);
  const found:{name:string;grams:number;nutrition:Nutrition}[]=[];
  for(const seg of segs){const gm=seg.match(/(\d+)\s*g/i);const g=gm?parseInt(gm[1]):150;const m=searchFoods(seg.replace(/\d+\s*g/gi,"").trim(),1)[0];if(m)found.push({name:m.name,grams:g,nutrition:scaleNutrition(m.per100g,g)});}
  const totals=found.reduce((a,i)=>({calories:a.calories+i.nutrition.calories,protein:a.protein+i.nutrition.protein,carbs:a.carbs+i.nutrition.carbs,fat:a.fat+i.nutrition.fat,fiber:a.fiber+i.nutrition.fiber,sugar:a.sugar+i.nutrition.sugar,sodium:a.sodium+i.nutrition.sodium,saturatedFat:a.saturatedFat+i.nutrition.saturatedFat,omega3:a.omega3+i.nutrition.omega3,vitaminC:a.vitaminC+i.nutrition.vitaminC}),{calories:0,protein:0,carbs:0,fat:0,fiber:0,sugar:0,sodium:0,saturatedFat:0,omega3:0,vitaminC:0});
  let score=50;score+=Math.min(20,totals.protein*0.5);score+=Math.min(15,totals.fiber*2);score+=Math.min(10,totals.vitaminC*0.2);if(totals.sodium>600)score-=Math.min(15,(totals.sodium-600)/60);if(totals.saturatedFat>10)score-=Math.min(15,(totals.saturatedFat-10)*1.5);score=Math.max(0,Math.min(100,Math.round(score)));
  return {mealDescription:desc,ingredients:found.map(i=>({name:i.name,grams:i.grams,calories:Math.round(i.nutrition.calories)})),totals,healthScore:{score,rating:score>=80?"Excellent":score>=60?"Good":score>=40?"Fair":"Poor"},flags:[...(totals.sodium>800?["HIGH_SODIUM"]:[]),...(totals.fiber<3?["LOW_FIBER"]:[]),...(totals.protein>30?["HIGH_PROTEIN"]:[]),...(totals.omega3>1?["OMEGA3_RICH"]:[])]};
}
ENDOFFILE

echo "✅ Lib files written."

# ── Components ────────────────────────────────────────────────────────────────
cat > $PROJECT/apps/web/src/components/ChatPanel.tsx << 'ENDOFFILE'
"use client";
import { useState, useRef, useEffect } from "react";
interface Message { role:"user"|"assistant"; content:string; }
const SUGGESTIONS = ["What are the macros in 200g grilled salmon?","Create a 3-day meal plan for weight loss","I'm 35, female with type 2 diabetes — what should I eat?","Analyze: 2 scrambled eggs, toast, and orange juice","How much protein do I need daily at age 28?"];
export default function ChatPanel() {
  const [messages, setMessages] = useState<Message[]>([{ role:"assistant", content:"👋 Hello! I'm **NutriAgent**, your AI nutrition assistant.\n\nI can help you with:\n- 🥗 **Personalized meal plans**\n- 🔍 **Food nutrition lookup**\n- 📊 **Meal analysis with health score**\n- 💊 **Daily nutrient recommendations**\n\nTry asking me anything about nutrition!" }]);
  const [input, setInput] = useState(""); const [loading, setLoading] = useState(false); const bottomRef = useRef<HTMLDivElement>(null);
  useEffect(() => { bottomRef.current?.scrollIntoView({ behavior:"smooth" }); }, [messages]);
  async function send(text?: string) {
    const t = (text??input).trim(); if(!t||loading) return;
    const next: Message[] = [...messages,{role:"user",content:t}]; setMessages(next); setInput(""); setLoading(true);
    try {
      const res = await fetch("/api/chat",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({messages:next.map(m=>({role:m.role,content:m.content}))})});
      const d = await res.json() as {reply?:string;error?:string};
      setMessages([...next,{role:"assistant",content:d.reply??d.error??"Sorry, something went wrong."}]);
    } catch(e){setMessages([...next,{role:"assistant",content:`Error: ${String(e)}`}]);}
    finally{setLoading(false);}
  }
  return (
    <div className="flex flex-col h-[calc(100vh-160px)] min-h-[500px]">
      <div className="flex-1 overflow-y-auto flex flex-col gap-3 pb-4">
        {messages.map((m,i)=>(
          <div key={i} className={`flex ${m.role==="user"?"justify-end":"justify-start"}`}>
            {m.role==="assistant"&&<div className="w-7 h-7 rounded-full bg-green-600 text-white text-xs flex items-center justify-center mr-2 mt-1 flex-shrink-0 font-bold">N</div>}
            <div className={m.role==="user"?"bubble-user":"bubble-ai"}><Fmt content={m.content}/></div>
          </div>
        ))}
        {loading&&<div className="flex justify-start"><div className="w-7 h-7 rounded-full bg-green-600 text-white text-xs flex items-center justify-center mr-2 mt-1 font-bold">N</div><div className="bubble-ai"><span className="inline-flex gap-1"><span className="w-2 h-2 rounded-full bg-gray-400 animate-bounce"/>  <span className="w-2 h-2 rounded-full bg-gray-400 animate-bounce [animation-delay:150ms]"/><span className="w-2 h-2 rounded-full bg-gray-400 animate-bounce [animation-delay:300ms]"/></span></div></div>}
        <div ref={bottomRef}/>
      </div>
      {messages.length<=1&&<div className="flex flex-wrap gap-2 mb-3">{SUGGESTIONS.map(s=><button key={s} onClick={()=>send(s)} className="text-xs bg-green-50 hover:bg-green-100 text-green-700 px-3 py-1.5 rounded-full border border-green-200 transition-colors">{s}</button>)}</div>}
      <div className="flex gap-2 pt-2 border-t border-gray-200">
        <input type="text" value={input} onChange={e=>setInput(e.target.value)} onKeyDown={e=>e.key==="Enter"&&!e.shiftKey&&send()} placeholder="Ask about nutrition, meals, diet plans…" className="flex-1 border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" disabled={loading}/>
        <button onClick={()=>send()} disabled={loading||!input.trim()} className="bg-green-600 text-white px-5 py-2.5 rounded-xl text-sm font-medium hover:bg-green-700 disabled:opacity-50 transition-colors">Send</button>
      </div>
    </div>
  );
}
function Fmt({content}:{content:string}){
  return <div className="space-y-1">{content.split("\n").map((line,i)=>{
    const parts=line.split(/\*\*(.+?)\*\*/g).map((p,j)=>j%2===1?<strong key={j}>{p}</strong>:<span key={j}>{p}</span>);
    if(line.startsWith("- ")||line.startsWith("• "))return<div key={i} className="flex gap-1"><span className="text-green-600 mt-0.5">•</span><span>{parts.slice(1)}</span></div>;
    if(line==="")return<div key={i} className="h-1"/>;
    return<p key={i}>{parts}</p>;
  })}</div>;
}
ENDOFFILE

cat > $PROJECT/apps/web/src/components/MealLogger.tsx << 'ENDOFFILE'
"use client";
import { useState } from "react";
import { logMealFromText, getAllEntries, type MealLogEntry } from "@/lib/mealStore";
const TYPES = ["breakfast","lunch","dinner","snack"] as const;
export default function MealLogger() {
  const [desc, setDesc] = useState(""); const [type, setType] = useState<typeof TYPES[number]>("lunch");
  const [result, setResult] = useState<{entry:MealLogEntry;flags:string[]}|null>(null);
  const [history, setHistory] = useState<MealLogEntry[]>([]);
  const [err, setErr] = useState("");
  function log() {
    if(!desc.trim()){setErr("Please describe your meal.");return;} setErr("");
    const r=logMealFromText("default",desc,type); setResult(r); setHistory(getAllEntries("default")); setDesc("");
  }
  return (
    <div className="space-y-6 max-w-2xl mx-auto">
      <div className="card">
        <h2 className="text-base font-semibold mb-4">🍽️ Log a Meal</h2>
        <p className="text-sm text-gray-500 mb-4">Describe your meal in natural language, e.g. <em>"2 scrambled eggs with toast and a banana"</em></p>
        <div className="space-y-3">
          <div><label className="text-xs font-medium text-gray-700 mb-1 block">Meal Type</label>
            <div className="flex gap-2">{TYPES.map(t=><button key={t} onClick={()=>setType(t)} className={`px-3 py-1.5 text-xs rounded-lg capitalize border transition-colors ${type===t?"bg-green-600 text-white border-green-600":"bg-white text-gray-600 border-gray-200 hover:border-green-400"}`}>{t}</button>)}</div>
          </div>
          <div><label className="text-xs font-medium text-gray-700 mb-1 block">Meal Description</label>
            <textarea value={desc} onChange={e=>setDesc(e.target.value)} placeholder="e.g. 2 eggs, toast, and a glass of orange juice" rows={3} className="w-full border border-gray-200 rounded-xl px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-green-500 resize-none"/>
          </div>
          {err&&<p className="text-xs text-red-600">{err}</p>}
          <button onClick={log} className="w-full bg-green-600 text-white py-2.5 rounded-xl text-sm font-medium hover:bg-green-700 transition-colors">Log Meal</button>
        </div>
      </div>
      {result&&(
        <div className="card border-green-200 bg-green-50">
          <div className="flex justify-between items-center mb-3"><h3 className="text-sm font-semibold text-green-800">✅ Meal Logged</h3><span className="text-xs text-green-600 capitalize">{result.entry.mealType}</span></div>
          {result.entry.items.length>0?(
            <table className="w-full text-xs mb-3"><thead><tr className="text-gray-500 border-b border-gray-200"><th className="text-left pb-1">Food</th><th className="text-right pb-1">g</th><th className="text-right pb-1">kcal</th><th className="text-right pb-1">P</th><th className="text-right pb-1">C</th><th className="text-right pb-1">F</th></tr></thead>
              <tbody>{result.entry.items.map((i,idx)=><tr key={idx} className="border-b border-gray-100"><td className="py-1">{i.name}</td><td className="text-right py-1 text-gray-600">{Math.round(i.grams)}</td><td className="text-right py-1 font-medium">{Math.round(i.calories)}</td><td className="text-right py-1 text-blue-600">{i.protein.toFixed(1)}g</td><td className="text-right py-1 text-orange-500">{i.carbs.toFixed(1)}g</td><td className="text-right py-1 text-yellow-600">{i.fat.toFixed(1)}g</td></tr>)}</tbody>
              <tfoot><tr className="font-semibold text-gray-800"><td className="pt-2">Total</td><td/><td className="text-right pt-2">{Math.round(result.entry.totals.calories)}</td><td className="text-right pt-2 text-blue-600">{result.entry.totals.protein.toFixed(1)}g</td><td className="text-right pt-2 text-orange-500">{result.entry.totals.carbs.toFixed(1)}g</td><td className="text-right pt-2 text-yellow-600">{result.entry.totals.fat.toFixed(1)}g</td></tr></tfoot>
            </table>
          ):<p className="text-xs text-gray-500 mb-3">No matching foods found for this description.</p>}
          {result.flags.length>0&&<div className="flex flex-wrap gap-1">{result.flags.map(f=><span key={f} className="text-xs bg-amber-100 text-amber-700 px-2 py-0.5 rounded-full">{f}</span>)}</div>}
        </div>
      )}
      {history.length>0&&<div className="card"><h3 className="text-sm font-semibold mb-3">Recent Meals</h3><div className="space-y-2">{history.slice(0,8).map(e=><div key={e.id} className="flex justify-between items-start border-b border-gray-100 pb-2 last:border-0"><div><p className="text-xs font-medium capitalize">{e.mealType} — {e.description.slice(0,50)}{e.description.length>50?"…":""}</p><p className="text-xs text-gray-500">{new Date(e.timestamp).toLocaleTimeString([],{hour:"2-digit",minute:"2-digit"})}</p></div><span className="text-xs font-semibold text-green-700 shrink-0 ml-4">{Math.round(e.totals.calories)} kcal</span></div>)}</div></div>}
    </div>
  );
}
ENDOFFILE

cat > $PROJECT/apps/web/src/components/DietTracker.tsx << 'ENDOFFILE'
"use client";
import { useState, useEffect } from "react";
import { getDailySummary, logMealFromText } from "@/lib/mealStore";
interface Goals { calories:number; protein:number; carbs:number; fat:number; }
const DEF: Goals = { calories:2000, protein:50, carbs:260, fat:65 };
export default function DietTracker() {
  const [goals, setGoals] = useState<Goals>(DEF); const [editing, setEditing] = useState(false);
  const [summary, setSummary] = useState(getDailySummary("default",undefined,DEF)); const [quick, setQuick] = useState("");
  function refresh(g=goals){setSummary(getDailySummary("default",undefined,g));}
  useEffect(()=>{refresh();},[goals]);
  function logQuick(){if(!quick.trim())return;logMealFromText("default",quick);setQuick("");refresh();}
  const t=summary.totals;
  return (
    <div className="space-y-5 max-w-2xl mx-auto">
      <div className="card">
        <div className="flex justify-between items-start mb-4">
          <div><h2 className="text-base font-semibold">📊 Today&apos;s Nutrition</h2><p className="text-xs text-gray-500">{new Date().toLocaleDateString("en-US",{weekday:"long",month:"long",day:"numeric"})}</p></div>
          <button onClick={()=>setEditing(!editing)} className="text-xs text-green-600 hover:underline">{editing?"Save Goals":"Edit Goals"}</button>
        </div>
        {editing?<GoalEditor goals={goals} onChange={g=>{setGoals(g);}}/>:(
          <div className="space-y-3">
            <Bar label="Calories" cur={t.calories} goal={goals.calories} unit="kcal" color="bg-green-500"/>
            <Bar label="Protein"  cur={t.protein}  goal={goals.protein}  unit="g"    color="bg-blue-500"/>
            <Bar label="Carbs"    cur={t.carbs}    goal={goals.carbs}    unit="g"    color="bg-orange-400"/>
            <Bar label="Fat"      cur={t.fat}      goal={goals.fat}      unit="g"    color="bg-yellow-500"/>
          </div>
        )}
      </div>
      <div className="card"><h3 className="text-sm font-semibold mb-2">Quick Log</h3>
        <div className="flex gap-2"><input value={quick} onChange={e=>setQuick(e.target.value)} onKeyDown={e=>e.key==="Enter"&&logQuick()} placeholder="Describe a meal to add it…" className="flex-1 border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"/><button onClick={logQuick} className="bg-green-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-green-700">Add</button></div>
      </div>
      {summary.insights.length>0&&<div className="card bg-amber-50 border-amber-200"><h3 className="text-sm font-semibold text-amber-800 mb-2">Insights</h3><ul className="space-y-1">{summary.insights.map((ins,i)=><li key={i} className="text-xs text-amber-700">{ins}</li>)}</ul></div>}
      {summary.entries.length>0&&<div className="card"><h3 className="text-sm font-semibold mb-3">Today&apos;s Meals ({summary.entries.length})</h3><div className="space-y-2">{summary.entries.map(e=><div key={e.id} className="flex justify-between items-start border-b border-gray-100 pb-2 last:border-0"><div><p className="text-xs font-medium capitalize">{e.mealType}</p><p className="text-xs text-gray-500">{e.description.slice(0,60)}{e.description.length>60?"…":""}</p></div><div className="text-right shrink-0 ml-3"><p className="text-xs font-semibold text-green-700">{Math.round(e.totals.calories)} kcal</p><p className="text-xs text-gray-400">P:{e.totals.protein.toFixed(0)}g C:{e.totals.carbs.toFixed(0)}g F:{e.totals.fat.toFixed(0)}g</p></div></div>)}</div></div>}
    </div>
  );
}
function Bar({label,cur,goal,unit,color}:{label:string;cur:number;goal:number;unit:string;color:string}){
  const pct=Math.min(100,Math.round(cur/goal*100)); const over=cur>goal;
  return <div><div className="flex justify-between text-xs mb-1"><span className="font-medium text-gray-700">{label}</span><span className={over?"text-red-500 font-semibold":"text-gray-500"}>{Math.round(cur)}/{goal} {unit} ({pct}%)</span></div><div className="macro-bar"><div className={`macro-bar-fill ${over?"bg-red-400":color}`} style={{width:`${pct}%`}}/></div></div>;
}
function GoalEditor({goals,onChange}:{goals:Goals;onChange:(g:Goals)=>void}){
  return <div className="grid grid-cols-2 gap-3">{(Object.keys(goals)as Array<keyof Goals>).map(k=><div key={k}><label className="text-xs font-medium text-gray-700 capitalize mb-1 block">{k} {k==="calories"?"(kcal)":"(g)"}</label><input type="number" value={goals[k]} onChange={e=>onChange({...goals,[k]:parseInt(e.target.value)||0})} className="w-full border border-gray-200 rounded-lg px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"/></div>)}</div>;
}
ENDOFFILE

cat > $PROJECT/apps/web/src/components/FoodSearch.tsx << 'ENDOFFILE'
"use client";
import { useState } from "react";
import { FOOD_DATABASE, searchFoods, scaleNutrition } from "@/lib/foodDatabase";
const CATS = ["all","protein","grain","vegetable","fruit","dairy","legume","nuts_seeds","fat"];
export default function FoodSearch() {
  const [q, setQ] = useState(""); const [g, setG] = useState(100); const [cat, setCat] = useState("all");
  const [sel, setSel] = useState<ReturnType<typeof searchFoods>[0]|null>(null);
  const results = q.trim() ? searchFoods(q,10).filter(f=>cat==="all"||f.category===cat) : FOOD_DATABASE.filter(f=>cat==="all"||f.category===cat).slice(0,12);
  const sc = sel ? scaleNutrition(sel.per100g, g) : null;
  return (
    <div className="space-y-5 max-w-3xl mx-auto">
      <div className="card">
        <h2 className="text-base font-semibold mb-3">🔍 Food Nutrition Search</h2>
        <div className="flex gap-2 mb-3">
          <input type="text" value={q} onChange={e=>setQ(e.target.value)} placeholder="Search food e.g. 'chicken breast', 'avocado'…" className="flex-1 border border-gray-200 rounded-xl px-4 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"/>
          <div className="flex items-center gap-2 border border-gray-200 rounded-xl px-3 py-2"><span className="text-xs text-gray-500">g:</span><input type="number" value={g} min={1} max={2000} onChange={e=>setG(parseInt(e.target.value)||100)} className="w-14 text-sm text-right outline-none"/></div>
        </div>
        <div className="flex flex-wrap gap-1.5">{CATS.map(c=><button key={c} onClick={()=>setCat(c)} className={`text-xs px-3 py-1 rounded-full capitalize border transition-colors ${cat===c?"bg-green-600 text-white border-green-600":"bg-white text-gray-600 border-gray-200 hover:border-green-400"}`}>{c.replace("_"," ")}</button>)}</div>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="card"><h3 className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-3">{results.length} result{results.length!==1?"s":""}</h3>
          <div className="space-y-1 max-h-80 overflow-y-auto">{results.map(f=><button key={f.id} onClick={()=>setSel(f)} className={`w-full text-left px-3 py-2 rounded-lg text-sm transition-colors flex justify-between items-center ${sel?.id===f.id?"bg-green-50 border border-green-200 text-green-800":"hover:bg-gray-50 text-gray-700"}`}><div><p className="font-medium">{f.name}</p><p className="text-xs text-gray-400 capitalize">{f.category.replace("_"," ")}</p></div><span className="text-xs text-gray-500 shrink-0 ml-2">{f.per100g.calories} kcal/100g</span></button>)}
            {results.length===0&&<p className="text-sm text-gray-400 py-4 text-center">No foods match your search.</p>}
          </div>
        </div>
        <div>{sel&&sc?(<div className="card space-y-4">
          <div><h3 className="text-sm font-semibold">{sel.name}</h3><p className="text-xs text-gray-500">Per {g} g serving</p></div>
          <div className="grid grid-cols-2 gap-2">
            {[["Calories",sc.calories,"kcal"],["Protein",sc.protein,"g"],["Carbs",sc.carbs,"g"],["Fat",sc.fat,"g"],["Fiber",sc.fiber,"g"]].map(([l,v,u])=><div key={String(l)} className={`rounded-lg p-2 ${l==="Calories"?"col-span-2 bg-green-50":"bg-gray-50"}`}><p className="text-xs text-gray-500">{l}</p><p className={`text-lg font-bold ${l==="Calories"?"text-green-700":"text-gray-800"}`}>{v} <span className="text-xs font-normal text-gray-500">{u}</span></p></div>)}
          </div>
          <div><p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Micronutrients</p>
            <div className="space-y-1 text-xs">{[["Sodium",sc.sodium,"mg"],["Calcium",sc.calcium,"mg"],["Iron",sc.iron,"mg"],["Vitamin C",sc.vitaminC,"mg"],["Vitamin D",sc.vitaminD,"µg"],["Potassium",sc.potassium,"mg"],["Omega-3",sc.omega3,"g"]].map(([k,v,u])=><div key={String(k)} className="flex justify-between border-b border-gray-100 pb-1"><span className="text-gray-600">{k}</span><span className="font-medium">{v} {u}</span></div>)}</div>
          </div>
          <div className="flex flex-wrap gap-1">{sel.tags.map(t=><span key={t} className="text-xs bg-gray-100 text-gray-600 px-2 py-0.5 rounded-full">{t}</span>)}</div>
        </div>):<div className="card flex items-center justify-center h-40"><p className="text-sm text-gray-400">← Select a food to see details</p></div>}</div>
      </div>
    </div>
  );
}
ENDOFFILE

cat > $PROJECT/apps/web/src/components/DietPlanWizard.tsx << 'ENDOFFILE'
"use client";
import { useState } from "react";
interface Profile { age:string;sex:"male"|"female"|"other";weight_kg:string;height_cm:string;activity_level:string;goal:string;health_conditions:string;allergies:string;cuisine_preferences:string;days:string; }
const ACT_OPTS=[{value:"sedentary",label:"Sedentary"},{value:"lightly_active",label:"Lightly active"},{value:"moderately_active",label:"Moderately active"},{value:"very_active",label:"Very active"},{value:"extra_active",label:"Extra active"}];
const GOAL_OPTS=[{value:"weight_loss",label:"Weight Loss"},{value:"maintenance",label:"Maintenance"},{value:"muscle_gain",label:"Muscle Gain"},{value:"endurance",label:"Endurance"},{value:"general_health",label:"General Health"}];
const DEF: Profile = {age:"30",sex:"female",weight_kg:"65",height_cm:"165",activity_level:"moderately_active",goal:"general_health",health_conditions:"",allergies:"",cuisine_preferences:"Mediterranean",days:"3"};
function tdee(p:{age:number;sex:string;weight_kg:number;height_cm:number;activity_level:string;goal:string}){
  const bmr=p.sex==="male"?10*p.weight_kg+6.25*p.height_cm-5*p.age+5:10*p.weight_kg+6.25*p.height_cm-5*p.age-161;
  const mult:Record<string,number>={sedentary:1.2,lightly_active:1.375,moderately_active:1.55,very_active:1.725,extra_active:1.9};
  const adj:Record<string,number>={weight_loss:-500,maintenance:0,muscle_gain:300,endurance:200,general_health:0};
  return Math.round(bmr*(mult[p.activity_level]??1.55)+(adj[p.goal]??0));
}
const MEAL_TPLS=[{type:"Breakfast",pct:0.25,items:["Oatmeal","Banana","Greek Yogurt"]},{type:"Lunch",pct:0.35,items:["Chicken Breast","Brown Rice","Broccoli"]},{type:"Snack",pct:0.10,items:["Almonds","Apple"]},{type:"Dinner",pct:0.30,items:["Salmon","Quinoa","Spinach"]}];
export default function DietPlanWizard() {
  const [profile,setProfile]=useState<Profile>(DEF); const [step,setStep]=useState(1);
  const [plan,setPlan]=useState<{cal:number;protein:number;carbs:number;fat:number;days:number}|null>(null);
  const set=(k:keyof Profile,v:string)=>setProfile(p=>({...p,[k]:v}));
  function generate(){
    const cal=tdee({age:parseInt(profile.age),sex:profile.sex,weight_kg:parseFloat(profile.weight_kg),height_cm:parseFloat(profile.height_cm),activity_level:profile.activity_level,goal:profile.goal});
    let pPct=0.25,cPct=0.50; if(profile.goal==="muscle_gain"){pPct=0.30;cPct=0.45;} if(profile.goal==="weight_loss"){pPct=0.35;cPct=0.40;} if(profile.goal==="endurance"){pPct=0.20;cPct=0.60;}
    setPlan({cal,protein:Math.round(cal*pPct/4),carbs:Math.round(cal*cPct/4),fat:Math.round(cal*0.25/9),days:parseInt(profile.days)});
    setStep(3);
  }
  return (
    <div className="max-w-2xl mx-auto space-y-5">
      <div className="flex items-center gap-2">{[1,2,3].map(s=><><div className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold transition-colors ${step>=s?"bg-green-600 text-white":"bg-gray-200 text-gray-500"}`}>{s}</div>{s<3&&<div className={`h-0.5 w-12 ${step>s?"bg-green-600":"bg-gray-200"}`}/>}</>)}<span className="ml-2 text-xs text-gray-500">{step===1?"Basic Info":step===2?"Preferences":"Your Plan"}</span></div>
      {step===1&&<div className="card space-y-4">
        <h2 className="text-base font-semibold">📋 Personal Profile</h2>
        <div className="grid grid-cols-2 gap-4">
          <F label="Age (years)" type="number" value={profile.age} onChange={v=>set("age",v)}/>
          <div><label className="text-xs font-medium text-gray-700 mb-1 block">Sex</label><select value={profile.sex} onChange={e=>set("sex",e.target.value as Profile["sex"])} className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"><option value="female">Female</option><option value="male">Male</option><option value="other">Other</option></select></div>
          <F label="Weight (kg)" type="number" value={profile.weight_kg} onChange={v=>set("weight_kg",v)}/>
          <F label="Height (cm)" type="number" value={profile.height_cm} onChange={v=>set("height_cm",v)}/>
        </div>
        <div><label className="text-xs font-medium text-gray-700 mb-1 block">Activity Level</label><select value={profile.activity_level} onChange={e=>set("activity_level",e.target.value)} className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500">{ACT_OPTS.map(o=><option key={o.value} value={o.value}>{o.label}</option>)}</select></div>
        <div><label className="text-xs font-medium text-gray-700 mb-1 block">Goal</label><div className="grid grid-cols-2 gap-2">{GOAL_OPTS.map(g=><button key={g.value} onClick={()=>set("goal",g.value)} className={`py-2 text-xs rounded-lg border transition-colors ${profile.goal===g.value?"bg-green-600 text-white border-green-600":"bg-white text-gray-600 border-gray-200 hover:border-green-400"}`}>{g.label}</button>)}</div></div>
        <button onClick={()=>setStep(2)} className="w-full bg-green-600 text-white py-2.5 rounded-xl text-sm font-medium hover:bg-green-700">Next →</button>
      </div>}
      {step===2&&<div className="card space-y-4">
        <h2 className="text-base font-semibold">🥗 Dietary Preferences</h2>
        <F label="Health Conditions (comma-separated)" placeholder="e.g. type2_diabetes, hypertension" value={profile.health_conditions} onChange={v=>set("health_conditions",v)}/>
        <F label="Allergies (comma-separated)" placeholder="e.g. gluten, nuts, lactose" value={profile.allergies} onChange={v=>set("allergies",v)}/>
        <F label="Cuisine Preferences (comma-separated)" placeholder="e.g. Indian, Mediterranean, Vegan" value={profile.cuisine_preferences} onChange={v=>set("cuisine_preferences",v)}/>
        <div><label className="text-xs font-medium text-gray-700 mb-1 block">Plan Duration</label><div className="flex gap-2">{[1,3,5,7].map(d=><button key={d} onClick={()=>set("days",String(d))} className={`px-4 py-2 rounded-lg text-sm border transition-colors ${profile.days===String(d)?"bg-green-600 text-white border-green-600":"bg-white text-gray-600 border-gray-200"}`}>{d}d</button>)}</div></div>
        <div className="flex gap-3"><button onClick={()=>setStep(1)} className="flex-1 border border-gray-200 text-gray-600 py-2.5 rounded-xl text-sm hover:bg-gray-50">← Back</button><button onClick={generate} className="flex-1 bg-green-600 text-white py-2.5 rounded-xl text-sm font-medium hover:bg-green-700">Generate Plan ✨</button></div>
      </div>}
      {step===3&&plan&&<div className="space-y-4">
        <div className="card bg-green-50 border-green-200"><div className="flex justify-between"><div><h3 className="text-sm font-semibold text-green-800">{plan.days}-Day {profile.goal.replace("_"," ")} Plan</h3><p className="text-xs text-green-600">Target: {plan.cal} kcal/day</p></div><button onClick={()=>setStep(1)} className="text-xs text-green-600 hover:underline">Start Over</button></div>
          <div className="grid grid-cols-3 gap-3 mt-4">{[{l:"Protein",v:plan.protein,c:"text-blue-600"},{l:"Carbs",v:plan.carbs,c:"text-orange-500"},{l:"Fat",v:plan.fat,c:"text-yellow-600"}].map(m=><div key={m.l} className="text-center"><p className={`text-lg font-bold ${m.c}`}>{m.v}g</p><p className="text-xs text-gray-500">{m.l}/day</p></div>)}</div>
        </div>
        {Array.from({length:plan.days},(_,i)=><div key={i} className="card"><h4 className="text-sm font-semibold mb-3">Day {i+1} — {plan.cal} kcal</h4><div className="space-y-3">{MEAL_TPLS.map((m,j)=><div key={j} className="border-l-4 border-green-300 pl-3"><p className="text-xs font-semibold text-green-700">{m.type} — {Math.round(plan.cal*m.pct)} kcal</p><ul className="mt-1 space-y-0.5">{m.items.map((item,k)=><li key={k} className="text-xs text-gray-600">• {item}</li>)}</ul></div>)}</div></div>)}
        <p className="text-xs text-gray-400 text-center">Generated algorithmically. Consult a registered dietitian for medical-grade nutrition advice.</p>
      </div>}
    </div>
  );
}
function F({label,value,onChange,type="text",placeholder=""}:{label:string;value:string;onChange:(v:string)=>void;type?:string;placeholder?:string}){
  return <div><label className="text-xs font-medium text-gray-700 mb-1 block">{label}</label><input type={type} value={value} onChange={e=>onChange(e.target.value)} placeholder={placeholder} className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"/></div>;
}
ENDOFFILE

echo "✅ All components written."

# ==============================================================================
# FINAL STEPS
# ==============================================================================

echo ""
echo "=============================================="
echo "  ✅  NutriAgent project created successfully!"
echo "=============================================="
echo ""
echo "📂 Project location: ./$PROJECT"
echo ""
echo "Next steps:"
echo ""
echo "  1️⃣  Install dependencies:"
echo "      cd $PROJECT && npm install"
echo ""
echo "  2️⃣  Build the MCP server:"
echo "      npm run build --workspace=packages/mcp-server"
echo ""
echo "  3️⃣  Set up your API key:"
echo "      cp apps/web/.env.example apps/web/.env.local"
echo "      # then open apps/web/.env.local and add your OPENAI_API_KEY"
echo ""
echo "  4️⃣  Start the app:"
echo "      npm run dev --workspace=apps/web"
echo ""
echo "  5️⃣  Open in browser:"
echo "      http://localhost:3000"
echo ""


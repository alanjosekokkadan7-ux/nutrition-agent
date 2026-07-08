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

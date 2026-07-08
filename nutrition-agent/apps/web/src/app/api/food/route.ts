import { NextRequest, NextResponse } from "next/server";
import { searchFoods, scaleNutrition } from "@/lib/foodDatabase";
export async function GET(req: NextRequest) {
  const q = req.nextUrl.searchParams.get("q")??"";
  const g = parseInt(req.nextUrl.searchParams.get("g")??"100");
  if (!q.trim()) return NextResponse.json({ results:[] });
  return NextResponse.json({ results: searchFoods(q, 5).map(f => ({ id:f.id, name:f.name, category:f.category, per100g:f.per100g, perServing:{grams:g,...scaleNutrition(f.per100g,g)}, tags:f.tags })) });
}

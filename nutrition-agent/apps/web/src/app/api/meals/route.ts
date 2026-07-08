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

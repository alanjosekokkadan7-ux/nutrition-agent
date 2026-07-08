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

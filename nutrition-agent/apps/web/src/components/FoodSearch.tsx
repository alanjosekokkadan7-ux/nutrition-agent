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

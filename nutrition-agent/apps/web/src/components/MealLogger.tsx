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

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

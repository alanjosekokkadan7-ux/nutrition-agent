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

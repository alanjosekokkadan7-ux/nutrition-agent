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

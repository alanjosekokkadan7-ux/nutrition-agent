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

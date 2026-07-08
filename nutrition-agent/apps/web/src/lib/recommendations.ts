export async function getNutrientRecommendations(age:number,sex:"male"|"female",healthConditions:string[]=[],goal?:string){
  const isMale=sex==="male",isSenior=age>50;
  const p={calories:isMale?(isSenior?2200:2500):(isSenior?1800:2000),protein_g:isMale?56:46,fat_g:isMale?78:62,carbs_g:isMale?325:260,fiber_g:isMale?38:25,calcium_mg:isSenior?1200:1000,iron_mg:isMale?8:(age>=19&&age<=50?18:8),vitaminC_mg:isMale?90:75,vitaminD_mcg:isSenior?20:15,vitaminB12_mcg:2.4,sodium_mg:2300,notes:[] as string[]};
  const c=healthConditions.map(x=>x.toLowerCase());
  if(c.includes("pregnancy")){p.iron_mg=27;p.calories+=340;p.notes.push("Folic acid 600µg/day essential");}
  if(c.includes("type2_diabetes")||c.includes("diabetes")){p.carbs_g=Math.round(p.carbs_g*0.85);p.notes.push("Prefer low-GI carbs; limit refined sugar");}
  if(c.includes("hypertension")){p.sodium_mg=1500;p.notes.push("Follow DASH diet; limit sodium to 1500mg");}
  if(goal?.includes("muscle_gain")){p.protein_g=Math.round(p.calories*0.30/4);p.calories+=300;}
  if(goal?.includes("weight_loss")){p.calories=Math.round(p.calories*0.8);p.protein_g=Math.round(p.protein_g*1.2);}
  return {age,sex,healthConditions,goal:goal??"general_health",dailyRecommendations:p};
}

import type { Metadata } from "next";
import "./globals.css";
export const metadata: Metadata = { title: "NutriAgent — AI Nutrition Assistant", description: "Personalized diet plans, food lookup, and meal tracking." };
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return <html lang="en"><body className="bg-gray-50 text-gray-900 antialiased">{children}</body></html>;
}

import { Ionicons } from "@expo/vector-icons";
import type { ComponentProps } from "react";

type Name = "grid" | "trending-up" | "person" | "pulse" | "stats-chart" | "hardware-chip";

export function TabBarIcon({ name, color }: { name: Name; color: string }) {
  return <Ionicons name={name as ComponentProps<typeof Ionicons>["name"]} size={22} color={color} />;
}

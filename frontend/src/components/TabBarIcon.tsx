import { Ionicons } from "@expo/vector-icons";
import { IconProps } from "@expo/vector-icons/build/createIconSet";

type Name = "grid" | "trending-up" | "search" | "person";

export function TabBarIcon({ name, color }: { name: Name; color: string }) {
  return <Ionicons name={name as unknown as IconProps<string>["name"]} size={24} color={color} />;
}
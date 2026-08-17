import { ActivityIndicator, Pressable, ScrollView, Text, TextInput, TextInputProps, View, ViewProps } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import type { ReactNode } from "react";

export const C = {
  brand: "#16D39A",
  brandDark: "#0EA27B",
  bg: "#0A1120",
  deep: "#070C16",
  surface: "#0E1729",
  surface2: "#131F36",
  line: "#1C2B47",
  ink: "#E9EFF9",
  soft: "#95A6C3",
  faint: "#5E7093",
  up: "#16C784",
  down: "#EA3943",
  accent: "#4C8DFF",
  amber: "#F5A623",
  purple: "#8B5CF6",
};

export const PLAN_THEME: Record<string, { color: string; label: string }> = {
  free: { color: "#95A6C3", label: "FREE" },
  start: { color: "#4C8DFF", label: "START" },
  ultimate: { color: "#8B5CF6", label: "ULTIMATE" },
};

export function openUrl(url?: string | null) {
  if (url && typeof window !== "undefined") window.open(url, "_blank");
}

export function Screen({ children, ...props }: { children: ReactNode } & ViewProps) {
  return (
    <View className="flex-1 bg-night" {...props}>
      {children}
    </View>
  );
}

export function ScreenScroll({ children, pad = "px-4 pt-4 pb-8" }: { children: ReactNode; pad?: string }) {
  return (
    <ScrollView className="flex-1 bg-night" contentContainerStyle={{ paddingHorizontal: 16, paddingTop: 16, paddingBottom: 32 }}>
      {children}
    </ScrollView>
  );
}

export function Card({ children, className = "", ...props }: { children: ReactNode; className?: string } & ViewProps) {
  return (
    <View className={`bg-night-800 border border-night-600 rounded-2xl ${className}`} {...props}>
      {children}
    </View>
  );
}

export function SectionTitle({ children, action }: { children: ReactNode; action?: ReactNode }) {
  return (
    <View className="flex-row items-center justify-between mb-3 mt-2">
      <Text className="text-ink text-base font-bold tracking-wide">{children}</Text>
      {action}
    </View>
  );
}

export function Badge({ text, color = C.soft, filled = false }: { text: string; color?: string; filled?: boolean }) {
  return (
    <View
      className="px-2.5 py-1 rounded-full self-start"
      style={filled ? { backgroundColor: color } : { backgroundColor: color + "22", borderWidth: 1, borderColor: color + "55" }}
    >
      <Text className="text-[11px] font-bold tracking-wider" style={{ color: filled ? "#fff" : color }}>
        {text}
      </Text>
    </View>
  );
}

export function PrimaryButton({
  label,
  onPress,
  loading,
  disabled,
  color = C.brand,
  small,
}: {
  label: string;
  onPress: () => void;
  loading?: boolean;
  disabled?: boolean;
  color?: string;
  small?: boolean;
}) {
  return (
    <Pressable
      className={`rounded-xl items-center justify-center ${small ? "px-4 py-2" : "py-3.5"}`}
      style={{ backgroundColor: color, opacity: disabled || loading ? 0.55 : 1 }}
      onPress={onPress}
      disabled={disabled || loading}
    >
      {loading ? (
        <ActivityIndicator color="#04110C" />
      ) : (
        <Text className={`font-bold ${small ? "text-xs" : "text-base"}`} style={{ color: "#04110C" }}>
          {label}
        </Text>
      )}
    </Pressable>
  );
}

export function GhostButton({ label, onPress, color = C.soft, small }: { label: string; onPress: () => void; color?: string; small?: boolean }) {
  return (
    <Pressable
      className={`rounded-xl items-center justify-center border ${small ? "px-4 py-2" : "py-3.5"}`}
      style={{ borderColor: color + "66", backgroundColor: color + "14" }}
      onPress={onPress}
    >
      <Text className="font-semibold" style={{ color }}>
        {label}
      </Text>
    </Pressable>
  );
}

export function Input(props: TextInputProps) {
  return (
    <TextInput
      className="bg-night-700 border border-night-500 rounded-xl px-4 py-3.5 text-ink text-base mb-3"
      placeholderTextColor={C.faint}
      {...props}
    />
  );
}

export function StatCard({ label, value, color = C.ink }: { label: string; value: string; color?: string }) {
  return (
    <View className="flex-1 bg-night-800 border border-night-600 rounded-xl px-2 py-3 items-center">
      <Text className="text-xl font-bold" style={{ color }}>
        {value}
      </Text>
      <Text className="text-ink-faint text-[11px] mt-0.5">{label}</Text>
    </View>
  );
}

export function Empty({ text }: { text: string }) {
  return (
    <Card className="items-center py-8 px-4">
      <Ionicons name="bar-chart-outline" size={28} color={C.faint} />
      <Text className="text-ink-soft text-sm text-center mt-2">{text}</Text>
    </Card>
  );
}

export function Loading({ label }: { label?: string }) {
  return (
    <View className="items-center py-10">
      <ActivityIndicator color={C.brand} />
      {label ? <Text className="text-ink-soft text-sm mt-3">{label}</Text> : null}
    </View>
  );
}

export function FavoriteStar({ active, onPress, size = 26 }: { active: boolean; onPress: () => void; size?: number }) {
  return (
    <Pressable onPress={onPress} hitSlop={8} className="px-1">
      <Ionicons name={active ? "star" : "star-outline"} size={size} color={active ? "#F5A623" : C.faint} />
    </Pressable>
  );
}

export function MarketBadge({ market }: { market: string }) {
  const colors: Record<string, string> = {
    B3: "#4C8DFF",
    NASDAQ: "#16C784",
    NYSE: "#F5A623",
    CRYPTO: "#8B5CF6",
    FOREX: "#22D3EE",
    COMMODITY: "#FB923C",
  };
  return <Badge text={market} color={colors[market] || C.soft} />;
}

export function UpsellCard({ title, message, planLabel, onWhatsapp, onPlans }: { title: string; message: string; planLabel: string; onWhatsapp: () => void; onPlans: () => void }) {
  return (
    <Card className="p-5 items-center">
      <View className="w-14 h-14 rounded-2xl items-center justify-center mb-3" style={{ backgroundColor: C.amber + "1F" }}>
        <Ionicons name="lock-closed" size={26} color={C.amber} />
      </View>
      <Text className="text-ink text-lg font-bold text-center">{title}</Text>
      <Text className="text-ink-soft text-sm text-center mt-1 mb-4">{message}</Text>
      <Badge text={planLabel} color={C.amber} />
      <View className="flex-row gap-3 mt-5 w-full">
        <View className="flex-1">
          <PrimaryButton label="Ver planos" onPress={onPlans} color={C.brand} small />
        </View>
        <View className="flex-1">
          <GhostButton label="WhatsApp" onPress={onWhatsapp} color="#25D366" small />
        </View>
      </View>
    </Card>
  );
}

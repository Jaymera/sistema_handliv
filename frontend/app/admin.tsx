import "../src/global.css";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { Pressable, ScrollView, Text, View } from "react-native";

import { adminApi } from "@/api/client";
import { Badge, C, Card, Loading, SectionTitle } from "@/components/ui";

export default function AdminScreen() {
  const qc = useQueryClient();
  const { data: weights, isLoading: wLoading } = useQuery({ queryKey: ["weights"], queryFn: adminApi.weights });
  const { data: usersData, isLoading: uLoading } = useQuery({ queryKey: ["admin-users"], queryFn: adminApi.users });

  const toggleActive = async (userId: string, current: boolean) => {
    try {
      await adminApi.patchUser(userId, { is_active: !current });
      qc.invalidateQueries({ queryKey: ["admin-users"] });
    } catch {}
  };

  const changePlan = async (userId: string, planCode: string) => {
    try {
      await adminApi.patchUser(userId, { plan_code: planCode });
      qc.invalidateQueries({ queryKey: ["admin-users"] });
    } catch {}
  };

  const planColors: Record<string, string> = {
    free: "#95A6C3",
    start: "#4C8DFF",
    ultimate: "#8B5CF6",
  };

  return (
    <ScrollView className="flex-1 bg-night" contentContainerStyle={{ paddingHorizontal: 16, paddingTop: 18, paddingBottom: 32 }}>
      <Text className="text-ink-faint text-xs font-bold tracking-widest mb-1">HANDLIV · ADMIN</Text>
      <Text className="text-ink text-2xl font-bold mb-5">Painel Admin</Text>

      {/* Pesos */}
      <SectionTitle>Pesos do motor</SectionTitle>
      {wLoading ? (
        <Loading />
      ) : weights ? (
        <Card className="p-4 mb-6 flex-row justify-between">
          <View className="items-center flex-1">
            <Text className="text-accent text-lg font-bold">{Math.round(weights.technical_weight * 100)}%</Text>
            <Text className="text-ink-faint text-xs">Técnica</Text>
          </View>
          <View className="items-center flex-1">
            <Text className="text-up text-lg font-bold">{Math.round(weights.valuation_weight * 100)}%</Text>
            <Text className="text-ink-faint text-xs">Valuation</Text>
          </View>
          <View className="items-center flex-1">
            <Text className="text-amber text-lg font-bold">{Math.round(weights.sentiment_weight * 100)}%</Text>
            <Text className="text-ink-faint text-xs">Sentimento</Text>
          </View>
          <View className="items-center flex-1">
            <Text className="text-ink text-lg font-bold">{weights.min_confidence}</Text>
            <Text className="text-ink-faint text-xs">Conf. mín.</Text>
          </View>
        </Card>
      ) : null}

      {/* Usuários */}
      <SectionTitle>Usuários</SectionTitle>
      {uLoading ? (
        <Loading />
      ) : usersData && usersData.items.length > 0 ? (
        <View className="gap-3">
          {usersData.items.map((u) => (
            <Card key={u.id} className="p-4">
              <View className="flex-row justify-between items-start mb-3">
                <View className="flex-1">
                  <View className="flex-row items-center gap-2">
                    <Text className="text-ink font-bold text-base">{u.name}</Text>
                    {u.role === "super_admin" ? <Badge text="ADMIN" color={C.amber} /> : null}
                  </View>
                  <Text className="text-ink-soft text-sm">{u.email}</Text>
                  {u.last_login_at ? (
                    <Text className="text-ink-faint text-[11px] mt-0.5">
                      Último login: {new Date(u.last_login_at).toLocaleDateString("pt-BR")}
                    </Text>
                  ) : null}
                </View>
                <Badge text={u.is_active ? "ATIVO" : "INATIVO"} color={u.is_active ? C.up : C.down} />
              </View>

              <View className="flex-row items-center gap-2 mb-3">
                <Badge text={u.plan_name.toUpperCase()} color={planColors[u.plan_code] || C.soft} />
                <Text className="text-ink-faint text-xs">{u.subscription_status}</Text>
              </View>

              <View className="flex-row gap-2 flex-wrap">
                <Pressable
                  className="px-3 py-2 rounded-lg"
                  style={{ backgroundColor: u.is_active ? C.down + "22" : C.up + "22" }}
                  onPress={() => toggleActive(u.id, u.is_active)}
                >
                  <Text className="text-xs font-bold" style={{ color: u.is_active ? C.down : C.up }}>
                    {u.is_active ? "DESATIVAR" : "ATIVAR"}
                  </Text>
                </Pressable>
                {(["free", "start", "ultimate"] as const).map((code) => {
                  const active = u.plan_code === code;
                  return (
                    <Pressable
                      key={code}
                      className="px-3 py-2 rounded-lg"
                      style={{
                        backgroundColor: active ? (planColors[code] || C.accent) : C.surface2,
                      }}
                      onPress={() => changePlan(u.id, code)}
                    >
                      <Text className="text-xs font-bold" style={{ color: active ? "#fff" : C.soft }}>
                        {code.toUpperCase()}
                      </Text>
                    </Pressable>
                  );
                })}
              </View>
            </Card>
          ))}
        </View>
      ) : (
        <Text className="text-ink-soft">Nenhum usuário.</Text>
      )}
    </ScrollView>
  );
}

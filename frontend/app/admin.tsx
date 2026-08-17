import "../src/global.css";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Pressable, ScrollView, Text, TextInput, View } from "react-native";
import { useEffect, useState } from "react";

import { adminApi } from "@/api/client";
import { Badge, C, Card, GhostButton, Loading, PrimaryButton, SectionTitle } from "@/components/ui";

export default function AdminScreen() {
  const qc = useQueryClient();
  const { data: weights, isLoading: wLoading } = useQuery({ queryKey: ["weights"], queryFn: adminApi.weights });
  const { data: usersData, isLoading: uLoading } = useQuery({ queryKey: ["admin-users"], queryFn: adminApi.users });

  const [tech, setTech] = useState("");
  const [valu, setValu] = useState("");
  const [sent, setSent] = useState("");
  const [minConf, setMinConf] = useState("");
  const [saved, setSaved] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);

  useEffect(() => {
    if (weights) {
      setTech(String(Math.round(weights.technical_weight * 100)));
      setValu(String(Math.round(weights.valuation_weight * 100)));
      setSent(String(Math.round(weights.sentiment_weight * 100)));
      setMinConf(String(weights.min_confidence));
    }
  }, [weights]);

  const saveWeights = useMutation({
    mutationFn: () => {
      const t = parseInt(tech, 10) / 100;
      const v = parseInt(valu, 10) / 100;
      const s = parseInt(sent, 10) / 100;
      const total = t + v + s;
      if (Math.round(total * 100) !== 100) throw new Error(`A soma dos pesos deve ser 100% (atual: ${Math.round(total * 100)}%)`);
      return adminApi.updateWeights({
        technical_weight: t,
        valuation_weight: v,
        sentiment_weight: s,
        min_confidence: parseInt(minConf, 10) || 0,
      });
    },
    onSuccess: () => {
      setSaved(true);
      setSaveError(null);
      setTimeout(() => setSaved(false), 2500);
      qc.invalidateQueries({ queryKey: ["weights"] });
    },
    onError: (e: any) => setSaveError(e?.message ?? "Erro ao salvar"),
  });

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
        <Card className="p-4 mb-6">
          <View className="flex-row gap-2 mb-1">
            <WeightInput label="TÉCNICA %" value={tech} onChange={setTech} color={C.accent} />
            <WeightInput label="VALUATION %" value={valu} onChange={setValu} color={C.up} />
            <WeightInput label="SENTIMENTO %" value={sent} onChange={setSent} color={C.amber} />
          </View>
          <WeightInput label="CONFIANÇA MÍNIMA (0-100)" value={minConf} onChange={setMinConf} color={C.ink} />
          {saveError ? <Text className="text-down text-sm mb-2">{saveError}</Text> : null}
          {saved ? <Text className="text-up text-sm mb-2">Pesos salvos com sucesso!</Text> : null}
          <View className="flex-row gap-2">
            <View className="flex-1">
              <PrimaryButton label="Salvar pesos" small loading={saveWeights.isPending} onPress={() => saveWeights.mutate()} />
            </View>
            <View className="flex-1">
              <GhostButton
                label="Restaurar padrão"
                small
                color={C.soft}
                onPress={() => {
                  setTech("40"); setValu("35"); setSent("25"); setMinConf("50");
                }}
              />
            </View>
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

function WeightInput({ label, value, onChange, color }: { label: string; value: string; onChange: (v: string) => void; color: string }) {
  return (
    <View className="flex-1 mb-2">
      <Text className="text-[10px] font-bold mb-1" style={{ color }}>
        {label}
      </Text>
      <TextInput
        className="bg-night-700 border rounded-xl px-3 py-2.5 text-ink text-center"
        style={{ borderColor: color + "44" }}
        value={value}
        onChangeText={onChange}
        keyboardType="numeric"
      />
    </View>
  );
}

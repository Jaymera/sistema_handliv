import { Tabs } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { useQuery } from "@tanstack/react-query";

import { featuresApi } from "@/api/client";
import { C } from "@/components/ui";
import { TabBarIcon } from "@/components/TabBarIcon";

export default function TabLayout() {
  const { data: features } = useQuery({ queryKey: ["features"], queryFn: featuresApi.myFeatures, staleTime: 60_000 });
  const canMT5 = !!features?.features.trading_panel;
  const isUltimate = !!features?.features.auto_robot;

  return (
    <>
      <StatusBar style="light" />
      <Tabs
        screenOptions={{
          headerShown: false,
          tabBarActiveTintColor: C.brand,
          tabBarInactiveTintColor: C.faint,
          tabBarStyle: {
            backgroundColor: C.deep,
            borderTopColor: C.line,
            borderTopWidth: 1,
          },
          tabBarLabelStyle: { fontSize: 10, fontWeight: "700" },
          tabBarItemStyle: { paddingVertical: 4 },
        }}
      >
        <Tabs.Screen
          name="index"
          options={{
            title: "Início",
            tabBarIcon: ({ color }) => <TabBarIcon name="grid" color={color} />,
          }}
        />
        <Tabs.Screen
          name="markets"
          options={{
            title: "Mercados",
            tabBarIcon: ({ color }) => <TabBarIcon name="trending-up" color={color} />,
          }}
        />
        <Tabs.Screen
          name="trading"
          options={{
            title: "Painel",
            tabBarIcon: ({ color }) => <TabBarIcon name="pulse" color={color} />,
          }}
        />
        <Tabs.Screen
          name="trades"
          options={{
            title: "Trades",
            tabBarIcon: ({ color }) => <TabBarIcon name="stats-chart" color={color} />,
          }}
        />
        <Tabs.Screen
          name="mt5"
          options={{
            title: "MT5",
            tabBarIcon: ({ color }) => <TabBarIcon name="speedometer" color={color} />,
            ...(canMT5 ? {} : { href: null }),
          }}
        />
        <Tabs.Screen
          name="robot"
          options={{
            title: "Robô",
            tabBarIcon: ({ color }) => <TabBarIcon name="hardware-chip" color={color} />,
            ...(isUltimate ? {} : { href: null }),
          }}
        />
        <Tabs.Screen
          name="profile"
          options={{
            title: "Perfil",
            tabBarIcon: ({ color }) => <TabBarIcon name="person" color={color} />,
          }}
        />
      </Tabs>
    </>
  );
}

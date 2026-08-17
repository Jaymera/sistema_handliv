import { Tabs } from "expo-router";
import { StatusBar } from "expo-status-bar";

import { C } from "@/components/ui";
import { TabBarIcon } from "@/components/TabBarIcon";

export default function TabLayout() {
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
          name="robot"
          options={{
            title: "Robô",
            tabBarIcon: ({ color }) => <TabBarIcon name="hardware-chip" color={color} />,
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

import { StatusBar } from "expo-status-bar";
import { Tabs } from "expo-router";
import { useColorScheme } from "react-native";

import { TabBarIcon } from "@/components/TabBarIcon";

export default function TabLayout() {
  const scheme = useColorScheme();
  return (
    <>
      <StatusBar style={scheme === "dark" ? "light" : "dark"} />
      <Tabs
        screenOptions={{
          tabBarActiveTintColor: scheme === "dark" ? "#60a5fa" : "#1d4ed8",
          headerShown: true,
        }}
      >
        <Tabs.Screen
          name="index"
          options={{
            title: "Dashboard",
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
          name="recursos"
          options={{
            title: "Recursos",
            tabBarIcon: ({ color }) => <TabBarIcon name="rocket" color={color} />,
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

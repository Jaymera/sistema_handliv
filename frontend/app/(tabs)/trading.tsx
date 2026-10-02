import { Redirect } from "expo-router";

/** A aba Painel foi removida; os 6 recursos do plano moram agora no Perfil. */
export default function TradingPanelScreen() {
  return <Redirect href="/(tabs)/profile" />;
}

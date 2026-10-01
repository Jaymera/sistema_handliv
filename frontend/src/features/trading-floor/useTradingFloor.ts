import { useEffect, useMemo, useState } from 'react';
import { AppState, Platform } from 'react-native';
import { useIsFocused } from '@react-navigation/native';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { featuresApi, statsApi } from '@/api/client';
import { useAuthStore } from '@/state/authStore';
import { accountsToStations, accountSummary, chooseSource } from './model';
import { createDemo, advanceDemo } from './demo';
import type { FloorAccount } from './types';

export function canPollFloor(token: boolean, allowed: boolean, focused: boolean, active: boolean) {
  return token && allowed && focused && active;
}

export function useTradingFloor() {
  const user = useAuthStore(s => s.user);
  const token = useAuthStore(s => s.accessToken);
  const qc = useQueryClient();
  const focused = useIsFocused();
  const [active, setActive] = useState(AppState.currentState === 'active');
  const [requestedDemo, setRequestedDemo] = useState(false);
  const [count, setCount] = useState(20);
  const [frame, setFrame] = useState<ReturnType<typeof createDemo> | null>(null);
  const [accountId, setAccountId] = useState<string | null>(null);
  const [clock, setClock] = useState(Date.now());
  useEffect(() => {
    const update = () => setActive(Platform.OS === 'web' ? document.visibilityState === 'visible' && document.hasFocus() : AppState.currentState === 'active');
    const sub = AppState.addEventListener('change', update);
    if (Platform.OS === 'web') {
      document.addEventListener('visibilitychange', update);
      window.addEventListener('focus', update);
      window.addEventListener('blur', update);
    }
    update();
    return () => {
      sub.remove();
      if (Platform.OS === 'web') {
        document.removeEventListener('visibilitychange', update);
        window.removeEventListener('focus', update);
        window.removeEventListener('blur', update);
      }
    };
  }, []);
  // Scope every cache to the identity and remove old data, including in-flight queries.
  useEffect(() => {
    setRequestedDemo(false);
    setAccountId(null);
    const id = user?.id;
    return () => {
      for (const key of ['trading-floor-stats', 'trading-floor-features']) {
        void qc.cancelQueries({ queryKey: [key, id], exact: true });
        qc.removeQueries({ queryKey: [key, id], exact: true });
      }
    };
  }, [user?.id, !!token, qc]);
  const features = useQuery({
    queryKey: ['trading-floor-features', user?.id], queryFn: featuresApi.myFeatures,
    // Initial entitlement loading must survive window blur; only periodic polling pauses.
    enabled: !!token && !!user && focused, staleTime: 60_000,
    refetchInterval: focused && active ? 60_000 : false, refetchIntervalInBackground: false,
  });
  const allowed = !!token && !!user && (user.role === 'super_admin' || !!features.data?.features.trading_panel);
  const polling = canPollFloor(!!token, allowed, focused, active);
  const stats = useQuery({
    queryKey: ['trading-floor-stats', user?.id], queryFn: statsApi.list,
    // Fetch the first snapshot on entry, even when periodic refresh is paused.
    enabled: !!token && allowed && focused, staleTime: 10_000, refetchInterval: polling ? 15_000 : false,
    refetchIntervalInBackground: false, refetchOnWindowFocus: true,
  });
  const accounts: FloorAccount[] = allowed ? stats.data?.items ?? [] : [];
  const source = chooseSource(accounts, requestedDemo);
  const demo = source === 'demo';
  useEffect(() => {
    if (!focused || !active) return;
    const timer = setInterval(() => setClock(Date.now()), 15_000);
    return () => clearInterval(timer);
  }, [focused, active]);
  useEffect(() => {
    if (!demo) { setFrame(null); return; }
    setFrame(createDemo(count));
  }, [demo, count]);
  useEffect(() => {
    if (!demo || !active || !focused) return;
    let step = 0;
    const timer = setInterval(() => setFrame(previous => previous ? advanceDemo(previous, ++step) : createDemo(count)), 6000);
    return () => clearInterval(timer);
  }, [demo, count, active, focused]);
  const realStations = useMemo(() => accountsToStations(accounts, clock), [stats.data, allowed, clock]);
  const selectedAccount = accounts.find(a => a.id === accountId) ?? accounts[0];
  const stations = demo ? frame?.stations ?? [] : realStations;
  const summary = demo && frame ? frame.summary : accountSummary(selectedAccount, realStations);
  return { user, allowed, features, stats, accounts, selectedAccount, setAccountId, stations, summary,
    demo, requestedDemo, setRequestedDemo, count, setCount, events: demo ? frame?.events ?? [] : [], polling };
}

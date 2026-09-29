import { useEffect, useRef, useState } from 'react';
import { AccessibilityInfo, Animated, StyleSheet, Text, View } from 'react-native';
import Svg, { Circle, Defs, LinearGradient, Line, Path, Stop } from 'react-native-svg';

export const T = {
  bg: '#080D14', panel: '#101923', line: '#263442', ink: '#EBF4F3',
  muted: '#99ABB5', dim: '#778D99', green: '#29D9A0', cyan: '#65D9EB',
  amber: '#F4B75E', red: '#F07176', track: '#1D2B35',
};

export function CountUp({ value, color = T.ink, size = 42 }: { value: number; color?: string; size?: number }) {
  const [display, setDisplay] = useState(value);
  const animation = useRef(new Animated.Value(value));
  useEffect(() => {
    let alive = true;
    let subscription: string | null = null;
    const motion = animation.current;
    AccessibilityInfo.isReduceMotionEnabled().then(reduce => {
      if (!alive) return;
      if (reduce) { motion.setValue(value); setDisplay(value); return; }
      motion.setValue(0);
      subscription = motion.addListener(({ value: current }) => setDisplay(Math.round(current)));
      Animated.timing(motion, { toValue: value, duration: 620, useNativeDriver: false }).start();
    }).catch(() => setDisplay(value));
    return () => { alive = false; motion.stopAnimation(); if (subscription) motion.removeListener(subscription); };
  }, [value]);
  return <Text style={{ color, fontSize: size, fontWeight: '800', fontVariant: ['tabular-nums'] }}>{display}</Text>;
}

export function Meter({ value, color, height = 7 }: { value: number; color: string; height?: number }) {
  const fill = useRef(new Animated.Value(0));
  useEffect(() => {
    fill.current.setValue(0);
    const run = Animated.timing(fill.current, { toValue: 1, duration: 620, useNativeDriver: true });
    run.start();
    return () => run.stop();
  }, [value]);
  return <View style={{ height, borderRadius: height, overflow: 'hidden', backgroundColor: T.track }}>
    <Animated.View style={{ width: `${Math.min(100, Math.max(0, Number.isFinite(value) ? value : 0))}%`, height,
      borderRadius: height, backgroundColor: color, transform: [{ scaleX: fill.current }], transformOrigin: 'left center' }} />
  </View>;
}

export function Pulse({ color = T.green }: { color?: string }) {
  const opacity = useRef(new Animated.Value(1));
  useEffect(() => {
    let active = true;
    AccessibilityInfo.isReduceMotionEnabled().then(reduce => {
      if (!active || reduce) return;
      Animated.loop(Animated.sequence([
        Animated.timing(opacity.current, { toValue: 0.45, duration: 1000, useNativeDriver: true }),
        Animated.timing(opacity.current, { toValue: 1, duration: 1000, useNativeDriver: true }),
      ])).start();
    });
    return () => { active = false; opacity.current.stopAnimation(); };
  }, []);
  return <Animated.View style={{ width: 7, height: 7, borderRadius: 4, backgroundColor: color, opacity: opacity.current }} />;
}

export function PriceChart({ history, currency }: { history: { trade_date: string; close: number }[]; currency: string }) {
  const reveal = useRef(new Animated.Value(0));
  useEffect(() => {
    AccessibilityInfo.isReduceMotionEnabled().then(reduce => {
      if (reduce) reveal.current.setValue(1);
      else Animated.timing(reveal.current, { toValue: 1, duration: 540, useNativeDriver: true }).start();
    }).catch(() => reveal.current.setValue(1));
    return () => reveal.current.stopAnimation();
  }, []);
  const points = history.filter(item => Number.isFinite(item.close));
  if (points.length < 2) return <Text style={{ color: T.dim, padding: 18 }}>Histórico de preços indisponível.</Text>;
  const prices = points.map(item => item.close);
  const min = Math.min(...prices), max = Math.max(...prices);
  const span = max - min || 1;
  const xy = (p: number, i: number) => `${32 + i * 736 / (prices.length - 1)},${173 - (p - min) / span * 135}`;
  const line = points.map((p, i) => `${i === 0 ? 'M' : 'L'}${xy(p.close, i)}`).join(' ');
  const area = `${line} L768,184 L32,184 Z`;
  const up = prices[prices.length - 1] >= prices[0];
  const color = up ? T.green : T.red;
  const format = (v: number) => `${currency} ${v.toFixed(2)}`;
  const date = (s: string) => s.split('-').slice(1).reverse().join('/');
  return <View>
    <View style={styles.chartHeader}><Text style={styles.caption}>HISTÓRICO DE FECHAMENTO · {points.length} PREGÕES</Text>
      <Text style={{ color, fontSize: 12, fontWeight: '700' }}>{format(prices[prices.length - 1])}</Text></View>
    <Animated.View style={{ opacity: reveal.current }}><Svg width="100%" height={205} viewBox="0 0 800 205" preserveAspectRatio="none" accessibilityLabel="Gráfico de preços históricos">
      <Defs><LinearGradient id="terminalPriceFill" x1="0" x2="0" y1="0" y2="1">
        <Stop offset="0" stopColor={color} stopOpacity="0.3" /><Stop offset="1" stopColor={color} stopOpacity="0.01" />
      </LinearGradient></Defs>
      {[45, 95, 145, 184].map(y => <Line key={y} x1="32" y1={y} x2="768" y2={y} stroke={T.line} strokeWidth="1" strokeDasharray="4 6" />)}
      <Path d={area} fill="url(#terminalPriceFill)" />
      <Path d={line} fill="none" stroke={color} strokeWidth="2.5" strokeLinejoin="round" />
      <Circle cx="768" cy={173 - (prices[prices.length - 1] - min) / span * 135} r="5" fill={color} />
    </Svg></Animated.View>
    <View style={styles.chartFooter}><Text style={styles.caption}>{date(points[0].trade_date)}</Text>
      <Text style={styles.caption}>MÍN {format(min)}   ·   MÁX {format(max)}</Text>
      <Text style={styles.caption}>{date(points[points.length - 1].trade_date)}</Text></View>
  </View>;
}

const styles = StyleSheet.create({
  caption: { color: T.dim, fontSize: 10, fontWeight: '700', letterSpacing: 1 },
  chartHeader: { flexDirection: 'row', justifyContent: 'space-between', paddingHorizontal: 14, paddingTop: 14, alignItems: 'center' },
  chartFooter: { flexDirection: 'row', justifyContent: 'space-between', paddingHorizontal: 14, paddingBottom: 13 },
});

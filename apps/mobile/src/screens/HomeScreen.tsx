import React from 'react';
import { View, Text, StyleSheet } from 'react-native';

export default function HomeScreen() {
  return (
    <View style={styles.container}>
      <Text style={styles.emoji}>🎉</Text>
      <Text style={styles.title}>You're in!</Text>
      <Text style={styles.subtitle}>Signup / Login successful</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', alignItems: 'center', backgroundColor: '#fff' },
  emoji: { fontSize: 64, marginBottom: 16 },
  title: { fontSize: 32, fontWeight: '800', color: '#111', marginBottom: 8 },
  subtitle: { fontSize: 16, color: '#666' },
});

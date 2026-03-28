import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { signOut } from 'aws-amplify/auth';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import type { RootStackParamList } from '../navigation/types';

type Props = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'Home'>;
};

export default function HomeScreen({ navigation }: Props) {
  async function handleLogout() {
    await signOut();
    navigation.reset({ index: 0, routes: [{ name: 'Login' }] });
  }

  return (
    <View style={styles.container}>
      <Text style={styles.emoji}>🎉</Text>
      <Text style={styles.title}>You're in!</Text>
      <Text style={styles.subtitle}>Signup / Login successful</Text>
      <TouchableOpacity style={styles.button} onPress={handleLogout}>
        <Text style={styles.buttonText}>Logout</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', alignItems: 'center', backgroundColor: '#fff' },
  emoji: { fontSize: 64, marginBottom: 16 },
  title: { fontSize: 32, fontWeight: '800', color: '#111', marginBottom: 8 },
  subtitle: { fontSize: 16, color: '#666', marginBottom: 40 },
  button: {
    borderWidth: 1.5,
    borderColor: '#E8344E',
    borderRadius: 12,
    paddingVertical: 12,
    paddingHorizontal: 40,
  },
  buttonText: { color: '#E8344E', fontSize: 16, fontWeight: '600' },
});

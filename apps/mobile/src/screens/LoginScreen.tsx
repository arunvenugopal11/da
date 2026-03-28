import React, { useState } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
  Alert,
} from 'react-native';
import { signIn } from 'aws-amplify/auth';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import type { RootStackParamList } from '../navigation/types';

type Props = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'Login'>;
};

export default function LoginScreen({ navigation }: Props) {
  const [phone, setPhone] = useState('');
  const [loading, setLoading] = useState(false);

  const formattedPhone = `+91${phone.replace(/\D/g, '')}`;

  async function handleSendOtp() {
    if (phone.replace(/\D/g, '').length !== 10) {
      Alert.alert('Invalid number', 'Enter a 10-digit Indian mobile number.');
      return;
    }

    setLoading(true);
    try {
      await signIn({ username: formattedPhone, options: { authFlowType: 'CUSTOM_WITHOUT_SRP' } });
      navigation.navigate('Otp', { phoneNumber: formattedPhone });
    } catch (err: any) {
      // Cognito returns this when OTP is dispatched but sign-in step continues
      if (err.name === 'NotAuthorizedException' || err.name === 'UserNotFoundException') {
        Alert.alert('Error', err.message);
      } else {
        navigation.navigate('Otp', { phoneNumber: formattedPhone });
      }
    } finally {
      setLoading(false);
    }
  }

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <View style={styles.inner}>
        <Text style={styles.title}>Da</Text>
        <Text style={styles.subtitle}>Enter your mobile number</Text>

        <View style={styles.inputRow}>
          <View style={styles.prefix}>
            <Text style={styles.prefixText}>+91</Text>
          </View>
          <TextInput
            style={styles.input}
            placeholder="98765 43210"
            placeholderTextColor="#999"
            keyboardType="phone-pad"
            maxLength={10}
            value={phone}
            onChangeText={setPhone}
            autoFocus
          />
        </View>

        <TouchableOpacity
          style={[styles.button, loading && styles.buttonDisabled]}
          onPress={handleSendOtp}
          disabled={loading}
        >
          {loading ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <Text style={styles.buttonText}>Send OTP</Text>
          )}
        </TouchableOpacity>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#fff' },
  inner: { flex: 1, justifyContent: 'center', paddingHorizontal: 28 },
  title: { fontSize: 48, fontWeight: '800', color: '#E8344E', marginBottom: 8, textAlign: 'center' },
  subtitle: { fontSize: 16, color: '#444', marginBottom: 32, textAlign: 'center' },
  inputRow: {
    flexDirection: 'row',
    borderWidth: 1.5,
    borderColor: '#ddd',
    borderRadius: 12,
    overflow: 'hidden',
    marginBottom: 20,
  },
  prefix: {
    backgroundColor: '#f5f5f5',
    paddingHorizontal: 14,
    justifyContent: 'center',
    borderRightWidth: 1.5,
    borderRightColor: '#ddd',
  },
  prefixText: { fontSize: 16, fontWeight: '600', color: '#333' },
  input: { flex: 1, fontSize: 18, paddingVertical: 14, paddingHorizontal: 12, color: '#111' },
  button: {
    backgroundColor: '#E8344E',
    borderRadius: 12,
    paddingVertical: 16,
    alignItems: 'center',
  },
  buttonDisabled: { opacity: 0.6 },
  buttonText: { color: '#fff', fontSize: 16, fontWeight: '700' },
});

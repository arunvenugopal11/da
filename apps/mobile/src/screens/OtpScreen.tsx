import React, { useRef, useState } from 'react';
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
import { confirmSignIn, resendSignUpCode } from 'aws-amplify/auth';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import type { RouteProp } from '@react-navigation/native';
import type { RootStackParamList } from '../navigation/types';

type Props = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'Otp'>;
  route: RouteProp<RootStackParamList, 'Otp'>;
};

const OTP_LENGTH = 6;

export default function OtpScreen({ navigation, route }: Props) {
  const { phoneNumber } = route.params;
  const [otp, setOtp] = useState(Array(OTP_LENGTH).fill(''));
  const [loading, setLoading] = useState(false);
  const inputs = useRef<(TextInput | null)[]>([]);

  function handleChange(value: string, index: number) {
    const digit = value.replace(/\D/g, '').slice(-1);
    const next = [...otp];
    next[index] = digit;
    setOtp(next);
    if (digit && index < OTP_LENGTH - 1) inputs.current[index + 1]?.focus();
  }

  function handleKeyPress(key: string, index: number) {
    if (key === 'Backspace' && !otp[index] && index > 0) {
      inputs.current[index - 1]?.focus();
    }
  }

  async function handleVerify() {
    const code = otp.join('');
    if (code.length !== OTP_LENGTH) {
      Alert.alert('Enter all 6 digits');
      return;
    }
    setLoading(true);
    try {
      await confirmSignIn({ challengeResponse: code });
      navigation.reset({ index: 0, routes: [{ name: 'Home' }] });
    } catch (err: any) {
      Alert.alert('Invalid OTP', err.message ?? 'Please try again.');
    } finally {
      setLoading(false);
    }
  }

  async function handleResend() {
    try {
      await resendSignUpCode({ username: phoneNumber });
      Alert.alert('OTP resent', `A new code was sent to ${phoneNumber}`);
    } catch (err: any) {
      Alert.alert('Error', err.message);
    }
  }

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <View style={styles.inner}>
        <Text style={styles.title}>Verify OTP</Text>
        <Text style={styles.subtitle}>
          Enter the 6-digit code sent to{'\n'}
          <Text style={styles.phone}>{phoneNumber}</Text>
        </Text>

        <View style={styles.otpRow}>
          {otp.map((digit, i) => (
            <TextInput
              key={i}
              ref={(el) => { inputs.current[i] = el; }}
              style={[styles.cell, digit ? styles.cellFilled : null]}
              value={digit}
              onChangeText={(v) => handleChange(v, i)}
              onKeyPress={({ nativeEvent }) => handleKeyPress(nativeEvent.key, i)}
              keyboardType="number-pad"
              maxLength={1}
              selectTextOnFocus
              autoFocus={i === 0}
            />
          ))}
        </View>

        <TouchableOpacity
          style={[styles.button, loading && styles.buttonDisabled]}
          onPress={handleVerify}
          disabled={loading}
        >
          {loading ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <Text style={styles.buttonText}>Verify</Text>
          )}
        </TouchableOpacity>

        <TouchableOpacity style={styles.resend} onPress={handleResend}>
          <Text style={styles.resendText}>Didn't receive it? <Text style={styles.resendLink}>Resend OTP</Text></Text>
        </TouchableOpacity>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#fff' },
  inner: { flex: 1, justifyContent: 'center', paddingHorizontal: 28 },
  title: { fontSize: 28, fontWeight: '800', color: '#111', marginBottom: 8, textAlign: 'center' },
  subtitle: { fontSize: 15, color: '#666', marginBottom: 36, textAlign: 'center', lineHeight: 22 },
  phone: { fontWeight: '700', color: '#333' },
  otpRow: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 32 },
  cell: {
    width: 48,
    height: 56,
    borderWidth: 1.5,
    borderColor: '#ddd',
    borderRadius: 10,
    textAlign: 'center',
    fontSize: 22,
    fontWeight: '700',
    color: '#111',
  },
  cellFilled: { borderColor: '#E8344E' },
  button: {
    backgroundColor: '#E8344E',
    borderRadius: 12,
    paddingVertical: 16,
    alignItems: 'center',
    marginBottom: 20,
  },
  buttonDisabled: { opacity: 0.6 },
  buttonText: { color: '#fff', fontSize: 16, fontWeight: '700' },
  resend: { alignItems: 'center' },
  resendText: { color: '#888', fontSize: 14 },
  resendLink: { color: '#E8344E', fontWeight: '600' },
});

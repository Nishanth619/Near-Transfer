import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import QRCode from 'react-native-qrcode-svg';
import { BlurView } from 'expo-blur';
import { COLORS, RADIUS, SPACING } from '../utils/constants';

interface QRCodeDisplayProps {
  data: string;
  title?: string;
  expiresIn?: number;
}

export const QRCodeDisplay: React.FC<QRCodeDisplayProps> = ({ 
  data, 
  title = 'Scan to Connect',
  expiresIn = 300 // 5 minutes default
}) => {
  const [timeLeft, setTimeLeft] = useState(expiresIn);

  useEffect(() => {
    const timer = setInterval(() => {
      setTimeLeft(prev => {
        if (prev <= 1) {
          clearInterval(timer);
          return 0;
        }
        return prev - 1;
      });
    }, 1000);

    return () => clearInterval(timer);
  }, []);

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  return (
    <View style={styles.container}>
      <BlurView intensity={80} tint="light" style={styles.blurContainer}>
        <Text style={styles.title}>{title}</Text>
        
        <View style={styles.qrContainer}>
          <QRCode
            value={data}
            size={240}
            color={COLORS.textPrimary}
            backgroundColor={COLORS.surface}
          />
        </View>

        <View style={styles.timerContainer}>
          <Text style={styles.timerText}>Expires in {formatTime(timeLeft)}</Text>
        </View>
      </BlurView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    borderRadius: RADIUS.large,
    overflow: 'hidden',
    elevation: 8,
    shadowColor: COLORS.textPrimary,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.2,
    shadowRadius: 12,
  },
  blurContainer: {
    padding: SPACING.xl,
    alignItems: 'center',
  },
  title: {
    fontSize: 20,
    fontWeight: '700',
    color: COLORS.textPrimary,
    marginBottom: SPACING.lg,
  },
  qrContainer: {
    padding: SPACING.md,
    backgroundColor: COLORS.surface,
    borderRadius: RADIUS.base,
  },
  timerContainer: {
    marginTop: SPACING.lg,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    backgroundColor: COLORS.surfaceAlt,
    borderRadius: RADIUS.base,
  },
  timerText: {
    fontSize: 14,
    fontWeight: '600',
    color: COLORS.muted,
  },
});
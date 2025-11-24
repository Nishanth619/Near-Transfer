import React from 'react';
import { TouchableOpacity, Text, StyleSheet, ActivityIndicator, ViewStyle, TextStyle } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { COLORS, RADIUS, BUTTON_HEIGHT } from '../utils/constants';

interface GradientButtonProps {
  title: string;
  onPress: () => void;
  loading?: boolean;
  disabled?: boolean;
  style?: ViewStyle;
  textStyle?: TextStyle;
  variant?: 'primary' | 'secondary' | 'danger';
}

export const GradientButton: React.FC<GradientButtonProps> = ({
  title,
  onPress,
  loading = false,
  disabled = false,
  style,
  textStyle,
  variant = 'primary',
}) => {
  const colors = variant === 'primary' 
    ? [COLORS.accentStart, COLORS.accentEnd]
    : variant === 'danger'
    ? [COLORS.danger, '#FF6B6B']
    : [COLORS.primary, '#3A4B9E'];

  return (
    <TouchableOpacity
      onPress={onPress}
      disabled={disabled || loading}
      activeOpacity={0.8}
      style={[styles.container, style]}
    >
      <LinearGradient
        colors={colors}
        start={{ x: 0, y: 0 }}
        end={{ x: 1, y: 0 }}
        style={[styles.gradient, disabled && styles.disabled]}
      >
        {loading ? (
          <ActivityIndicator color={COLORS.surface} />
        ) : (
          <Text style={[styles.text, textStyle]}>{title}</Text>
        )}
      </LinearGradient>
    </TouchableOpacity>
  );
};

const styles = StyleSheet.create({
  container: {
    borderRadius: RADIUS.base,
    overflow: 'hidden',
    elevation: 8,
    shadowColor: COLORS.primary,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
  },
  gradient: {
    height: BUTTON_HEIGHT,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 24,
  },
  disabled: {
    opacity: 0.5,
  },
  text: {
    color: COLORS.surface,
    fontSize: 16,
    fontWeight: '600',
    letterSpacing: 0.5,
  },
});
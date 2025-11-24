import React, { useEffect } from 'react';
import { StyleSheet } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withRepeat,
  withTiming,
  interpolate,
} from 'react-native-reanimated';
import { LinearGradient } from 'expo-linear-gradient';
import { COLORS } from '../utils/constants';

export const AnimatedBackground: React.FC = () => {
  const animation = useSharedValue(0);

  useEffect(() => {
    animation.value = withRepeat(
      withTiming(1, { duration: 8000 }),
      -1,
      true
    );
  }, []);

  const animatedStyle = useAnimatedStyle(() => {
    const translateX = interpolate(animation.value, [0, 1], [-50, 50]);
    const translateY = interpolate(animation.value, [0, 1], [-30, 30]);

    return {
      transform: [
        { translateX },
        { translateY },
      ],
    };
  });

  return (
    <Animated.View style={[styles.container, animatedStyle]}>
      <LinearGradient
        colors={[COLORS.primary, COLORS.accentStart, COLORS.accentEnd]}
        start={{ x: 0, y: 0 }}
        end={{ x: 1, y: 1 }}
        style={styles.gradient}
      />
    </Animated.View>
  );
};

const styles = StyleSheet.create({
  container: {
    ...StyleSheet.absoluteFillObject,
    opacity: 0.15,
  },
  gradient: {
    flex: 1,
  },
});
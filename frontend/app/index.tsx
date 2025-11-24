import React from 'react';
import { View, Text, StyleSheet, SafeAreaView, TouchableOpacity, Dimensions } from 'react-native';
import { useRouter } from 'expo-router';
import { LinearGradient } from 'expo-linear-gradient';
import { MaterialIcons } from '@expo/vector-icons';
import Animated, { FadeIn, FadeInDown } from 'react-native-reanimated';
import { AnimatedBackground } from '../src/components/AnimatedBackground';
import { GradientButton } from '../src/components/GradientButton';
import { COLORS, SPACING, RADIUS } from '../src/utils/constants';

const { width } = Dimensions.get('window');

export default function HomeScreen() {
  const router = useRouter();

  return (
    <SafeAreaView style={styles.container}>
      <AnimatedBackground />
      
      <View style={styles.content}>
        <Animated.View entering={FadeIn.duration(1000)} style={styles.header}>
          <View style={styles.logoContainer}>
            <LinearGradient
              colors={[COLORS.accentStart, COLORS.accentEnd]}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 1 }}
              style={styles.logoGradient}
            >
              <MaterialIcons name="swap-horiz" size={48} color={COLORS.surface} />
            </LinearGradient>
          </View>
          
          <Text style={styles.title}>NearTransfer</Text>
          <Text style={styles.subtitle}>
            Lightning-fast file transfer between devices
          </Text>
        </Animated.View>

        <Animated.View entering={FadeInDown.delay(200).duration(800)} style={styles.actionsContainer}>
          <TouchableOpacity
            style={styles.actionCard}
            activeOpacity={0.9}
            onPress={() => router.push('/send')}
          >
            <LinearGradient
              colors={['rgba(0, 191, 166, 0.15)', 'rgba(0, 229, 255, 0.15)']}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 1 }}
              style={styles.cardGradient}
            >
              <View style={styles.iconCircle}>
                <MaterialIcons name="upload" size={32} color={COLORS.accentStart} />
              </View>
              <Text style={styles.cardTitle}>Send Files</Text>
              <Text style={styles.cardDescription}>
                Share files with nearby devices
              </Text>
            </LinearGradient>
          </TouchableOpacity>

          <TouchableOpacity
            style={styles.actionCard}
            activeOpacity={0.9}
            onPress={() => router.push('/receive')}
          >
            <LinearGradient
              colors={['rgba(39, 53, 123, 0.15)', 'rgba(58, 75, 158, 0.15)']}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 1 }}
              style={styles.cardGradient}
            >
              <View style={styles.iconCircle}>
                <MaterialIcons name="download" size={32} color={COLORS.primary} />
              </View>
              <Text style={styles.cardTitle}>Receive Files</Text>
              <Text style={styles.cardDescription}>
                Get files from nearby devices
              </Text>
            </LinearGradient>
          </TouchableOpacity>
        </Animated.View>

        <Animated.View entering={FadeInDown.delay(400).duration(800)} style={styles.featuresContainer}>
          <View style={styles.feature}>
            <MaterialIcons name="flash-on" size={20} color={COLORS.accentStart} />
            <Text style={styles.featureText}>Ultra Fast</Text>
          </View>
          <View style={styles.feature}>
            <MaterialIcons name="lock" size={20} color={COLORS.accentStart} />
            <Text style={styles.featureText}>Encrypted</Text>
          </View>
          <View style={styles.feature}>
            <MaterialIcons name="wifi-off" size={20} color={COLORS.accentStart} />
            <Text style={styles.featureText}>Peer-to-Peer</Text>
          </View>
        </Animated.View>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.surfaceAlt,
  },
  content: {
    flex: 1,
    paddingHorizontal: SPACING.lg,
  },
  header: {
    alignItems: 'center',
    marginTop: SPACING.xxl,
    marginBottom: SPACING.xl,
  },
  logoContainer: {
    marginBottom: SPACING.lg,
    elevation: 12,
    shadowColor: COLORS.accentStart,
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.4,
    shadowRadius: 16,
  },
  logoGradient: {
    width: 96,
    height: 96,
    borderRadius: 28,
    justifyContent: 'center',
    alignItems: 'center',
  },
  title: {
    fontSize: 36,
    fontWeight: '800',
    color: COLORS.textPrimary,
    marginBottom: SPACING.sm,
    letterSpacing: -0.5,
  },
  subtitle: {
    fontSize: 16,
    color: COLORS.muted,
    textAlign: 'center',
    paddingHorizontal: SPACING.xl,
  },
  actionsContainer: {
    flex: 1,
    justifyContent: 'center',
    gap: SPACING.lg,
  },
  actionCard: {
    borderRadius: RADIUS.large,
    overflow: 'hidden',
    elevation: 6,
    shadowColor: COLORS.textPrimary,
    shadowOffset: { width: 0, height: 3 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
  },
  cardGradient: {
    padding: SPACING.xl,
    alignItems: 'center',
    backgroundColor: COLORS.surface,
  },
  iconCircle: {
    width: 72,
    height: 72,
    borderRadius: 36,
    backgroundColor: COLORS.surfaceAlt,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: SPACING.md,
  },
  cardTitle: {
    fontSize: 24,
    fontWeight: '700',
    color: COLORS.textPrimary,
    marginBottom: SPACING.sm,
  },
  cardDescription: {
    fontSize: 14,
    color: COLORS.muted,
    textAlign: 'center',
  },
  featuresContainer: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    paddingVertical: SPACING.xl,
    backgroundColor: COLORS.surface,
    borderRadius: RADIUS.large,
    marginBottom: SPACING.lg,
    elevation: 2,
    shadowColor: COLORS.textPrimary,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.05,
    shadowRadius: 4,
  },
  feature: {
    alignItems: 'center',
    gap: SPACING.sm,
  },
  featureText: {
    fontSize: 12,
    fontWeight: '600',
    color: COLORS.textPrimary,
  },
});
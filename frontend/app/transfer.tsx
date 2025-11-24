import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet, SafeAreaView, ScrollView, TouchableOpacity } from 'react-native';
import { useRouter, useLocalSearchParams } from 'expo-router';
import { MaterialIcons } from '@expo/vector-icons';
import * as Progress from 'react-native-progress';
import Animated, { FadeIn, ZoomIn } from 'react-native-reanimated';
import { LinearGradient } from 'expo-linear-gradient';
import { FileCard } from '../src/components/FileCard';
import { GradientButton } from '../src/components/GradientButton';
import { useTransferStore } from '../src/store/transferStore';
import { COLORS, SPACING, RADIUS } from '../src/utils/constants';
import { formatBytes, formatSpeed, formatTime } from '../src/utils/helpers';

export default function TransferScreen() {
  const router = useRouter();
  const params = useLocalSearchParams();
  const type = params.type as 'send' | 'receive';

  const currentSession = useTransferStore(state => state.currentSession);
  const completeSession = useTransferStore(state => state.completeSession);

  const [elapsedTime, setElapsedTime] = useState(0);

  useEffect(() => {
    if (!currentSession) {
      router.replace('/');
      return;
    }

    const timer = setInterval(() => {
      setElapsedTime(prev => prev + 1);
    }, 1000);

    return () => clearInterval(timer);
  }, [currentSession]);

  useEffect(() => {
    // Check if all files are completed
    if (currentSession?.files.every(f => f.status === 'completed')) {
      setTimeout(() => {
        completeSession();
        router.replace('/');
      }, 2000);
    }
  }, [currentSession?.files]);

  if (!currentSession) {
    return null;
  }

  const overallProgress = currentSession.totalSize > 0
    ? (currentSession.transferredSize / currentSession.totalSize) * 100
    : 0;

  const averageSpeed = elapsedTime > 0
    ? currentSession.transferredSize / elapsedTime
    : 0;

  const eta = averageSpeed > 0
    ? (currentSession.totalSize - currentSession.transferredSize) / averageSpeed
    : 0;

  const isComplete = currentSession.status === 'completed' || 
    currentSession.files.every(f => f.status === 'completed');

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.scrollContent} showsVerticalScrollIndicator={false}>
        <Animated.View entering={FadeIn.duration(600)} style={styles.header}>
          <TouchableOpacity onPress={() => router.back()} style={styles.backButton}>
            <MaterialIcons name="arrow-back" size={24} color={COLORS.textPrimary} />
          </TouchableOpacity>
          <Text style={styles.title}>
            {type === 'send' ? 'Sending Files' : 'Receiving Files'}
          </Text>
          <View style={styles.placeholder} />
        </Animated.View>

        <Animated.View entering={ZoomIn.delay(200)} style={styles.statusCard}>
          <LinearGradient
            colors={isComplete 
              ? [COLORS.success, '#22C55E']
              : [COLORS.accentStart, COLORS.accentEnd]
            }
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 0 }}
            style={styles.statusGradient}
          >
            <MaterialIcons 
              name={isComplete ? 'check-circle' : 'sync'} 
              size={48} 
              color={COLORS.surface} 
            />
            <Text style={styles.statusTitle}>
              {isComplete ? 'Transfer Complete!' : 'Transferring...'}
            </Text>
            <Text style={styles.statusPercentage}>
              {Math.round(overallProgress)}%
            </Text>
          </LinearGradient>
        </Animated.View>

        <Animated.View entering={FadeIn.delay(400)} style={styles.progressSection}>
          <Progress.Bar
            progress={overallProgress / 100}
            width={null}
            height={12}
            color={isComplete ? COLORS.success : COLORS.accentStart}
            unfilledColor={COLORS.surfaceAlt}
            borderWidth={0}
            borderRadius={6}
          />

          <View style={styles.statsContainer}>
            <View style={styles.stat}>
              <MaterialIcons name="speed" size={20} color={COLORS.accentStart} />
              <Text style={styles.statLabel}>Speed</Text>
              <Text style={styles.statValue}>{formatSpeed(averageSpeed)}</Text>
            </View>
            
            <View style={styles.stat}>
              <MaterialIcons name="schedule" size={20} color={COLORS.accentStart} />
              <Text style={styles.statLabel}>Time</Text>
              <Text style={styles.statValue}>{formatTime(elapsedTime)}</Text>
            </View>
            
            <View style={styles.stat}>
              <MaterialIcons name="timer" size={20} color={COLORS.accentStart} />
              <Text style={styles.statLabel}>ETA</Text>
              <Text style={styles.statValue}>
                {isComplete ? '--' : formatTime(eta)}
              </Text>
            </View>
          </View>
        </Animated.View>

        <Animated.View entering={FadeIn.delay(600)} style={styles.filesSection}>
          <Text style={styles.sectionTitle}>Files</Text>
          {currentSession.files.map((file) => (
            <FileCard key={file.id} file={file} />
          ))}
        </Animated.View>

        {isComplete && (
          <Animated.View entering={FadeIn.delay(800)} style={styles.completeSection}>
            <Text style={styles.completeText}>
              Successfully transferred {currentSession.files.length} file(s)
            </Text>
            <Text style={styles.completeSubtext}>
              Total: {formatBytes(currentSession.totalSize)}
            </Text>
          </Animated.View>
        )}
      </ScrollView>

      {isComplete && (
        <View style={styles.footer}>
          <GradientButton
            title="Done"
            onPress={() => {
              completeSession();
              router.replace('/');
            }}
          />
        </View>
      )}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.surfaceAlt,
  },
  scrollContent: {
    paddingHorizontal: SPACING.lg,
    paddingBottom: 120,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingTop: SPACING.md,
    paddingBottom: SPACING.lg,
  },
  backButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: COLORS.surface,
    justifyContent: 'center',
    alignItems: 'center',
    elevation: 2,
    shadowColor: COLORS.textPrimary,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
  },
  title: {
    fontSize: 24,
    fontWeight: '700',
    color: COLORS.textPrimary,
  },
  placeholder: {
    width: 40,
  },
  statusCard: {
    borderRadius: RADIUS.large,
    overflow: 'hidden',
    marginBottom: SPACING.xl,
    elevation: 8,
    shadowColor: COLORS.accentStart,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 12,
  },
  statusGradient: {
    padding: SPACING.xl,
    alignItems: 'center',
  },
  statusTitle: {
    fontSize: 24,
    fontWeight: '700',
    color: COLORS.surface,
    marginTop: SPACING.md,
    marginBottom: SPACING.sm,
  },
  statusPercentage: {
    fontSize: 48,
    fontWeight: '800',
    color: COLORS.surface,
  },
  progressSection: {
    marginBottom: SPACING.xl,
  },
  statsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    marginTop: SPACING.lg,
    backgroundColor: COLORS.surface,
    borderRadius: RADIUS.large,
    padding: SPACING.lg,
    elevation: 2,
    shadowColor: COLORS.textPrimary,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.05,
    shadowRadius: 4,
  },
  stat: {
    alignItems: 'center',
    gap: SPACING.xs,
  },
  statLabel: {
    fontSize: 12,
    color: COLORS.muted,
    fontWeight: '600',
  },
  statValue: {
    fontSize: 14,
    fontWeight: '700',
    color: COLORS.textPrimary,
  },
  filesSection: {
    marginBottom: SPACING.xl,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '700',
    color: COLORS.textPrimary,
    marginBottom: SPACING.md,
  },
  completeSection: {
    alignItems: 'center',
    padding: SPACING.xl,
    backgroundColor: COLORS.surface,
    borderRadius: RADIUS.large,
    marginBottom: SPACING.lg,
  },
  completeText: {
    fontSize: 16,
    fontWeight: '600',
    color: COLORS.success,
    textAlign: 'center',
    marginBottom: SPACING.sm,
  },
  completeSubtext: {
    fontSize: 14,
    color: COLORS.muted,
  },
  footer: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    padding: SPACING.lg,
    backgroundColor: COLORS.surface,
    borderTopLeftRadius: RADIUS.large,
    borderTopRightRadius: RADIUS.large,
    elevation: 8,
    shadowColor: COLORS.textPrimary,
    shadowOffset: { width: 0, height: -2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
  },
});
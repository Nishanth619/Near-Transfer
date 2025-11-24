import React, { useState } from 'react';
import { View, Text, StyleSheet, SafeAreaView, ScrollView, TouchableOpacity, Alert } from 'react-native';
import { useRouter } from 'expo-router';
import { MaterialIcons } from '@expo/vector-icons';
import Animated, { FadeIn, SlideInRight } from 'react-native-reanimated';
import { FileService } from '../src/services/file/FileService';
import { TransferManager } from '../src/services/webrtc/TransferManager';
import { GradientButton } from '../src/components/GradientButton';
import { FileCard } from '../src/components/FileCard';
import { QRCodeDisplay } from '../src/components/QRCodeDisplay';
import { useTransferStore } from '../src/store/transferStore';
import { FileItem } from '../src/types';
import { COLORS, SPACING, RADIUS } from '../src/utils/constants';
import { compressString } from '../src/utils/helpers';

export default function SendScreen() {
  const router = useRouter();
  const [files, setFiles] = useState<FileItem[]>([]);
  const [qrData, setQrData] = useState<string | null>(null);
  const [isGenerating, setIsGenerating] = useState(false);
  const [transferManager] = useState(() => new TransferManager());
  const fileService = new FileService();

  const createSession = useTransferStore(state => state.createSession);
  const setError = useTransferStore(state => state.setError);

  const handlePickFiles = async () => {
    try {
      const selectedFiles = await fileService.pickFiles();
      if (selectedFiles.length > 0) {
        setFiles(selectedFiles);
      }
    } catch (error) {
      Alert.alert('Error', 'Failed to pick files');
    }
  };

  const handleGenerateQR = async () => {
    if (files.length === 0) {
      Alert.alert('No Files', 'Please select files to send');
      return;
    }

    setIsGenerating(true);
    try {
      // Initialize WebRTC and get offer
      const offerSdp = await transferManager.initializeAsSender();
      
      // Create session data
      const sessionData = {
        type: 'offer',
        sdp: compressString(offerSdp),
        fileCount: files.length,
        timestamp: Date.now(),
      };

      // Generate QR code data
      const qrString = JSON.stringify(sessionData);
      setQrData(qrString);

      // Create transfer session
      createSession('send', files);

      // Wait for answer from receiver
      // This would typically come from scanning a return QR or through another mechanism
      // For now, we'll navigate to transfer screen
      setTimeout(() => {
        router.push({
          pathname: '/transfer',
          params: { type: 'send' }
        });
      }, 1000);

    } catch (error) {
      console.error('Error generating QR:', error);
      setError('Failed to generate connection code');
      Alert.alert('Error', 'Failed to create connection');
    } finally {
      setIsGenerating(false);
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.scrollContent} showsVerticalScrollIndicator={false}>
        <Animated.View entering={FadeIn.duration(600)} style={styles.header}>
          <TouchableOpacity onPress={() => router.back()} style={styles.backButton}>
            <MaterialIcons name="arrow-back" size={24} color={COLORS.textPrimary} />
          </TouchableOpacity>
          <Text style={styles.title}>Send Files</Text>
          <View style={styles.placeholder} />
        </Animated.View>

        {files.length === 0 ? (
          <Animated.View entering={SlideInRight.delay(200)} style={styles.emptyState}>
            <View style={styles.emptyIconContainer}>
              <MaterialIcons name="folder-open" size={64} color={COLORS.muted} />
            </View>
            <Text style={styles.emptyTitle}>No Files Selected</Text>
            <Text style={styles.emptyDescription}>
              Select files you want to send to another device
            </Text>
          </Animated.View>
        ) : (
          <Animated.View entering={SlideInRight.delay(200)} style={styles.filesContainer}>
            <Text style={styles.sectionTitle}>
              {files.length} {files.length === 1 ? 'File' : 'Files'} Selected
            </Text>
            {files.map((file) => (
              <FileCard key={file.id} file={file} />
            ))}
          </Animated.View>
        )}

        {qrData && !isGenerating && (
          <Animated.View entering={FadeIn.duration(800)} style={styles.qrSection}>
            <QRCodeDisplay data={qrData} title="Scan to Connect" />
            <Text style={styles.qrInstruction}>
              Have the receiver scan this QR code to start transfer
            </Text>
          </Animated.View>
        )}
      </ScrollView>

      <View style={styles.footer}>
        {files.length > 0 && !qrData ? (
          <GradientButton
            title="Generate Connection Code"
            onPress={handleGenerateQR}
            loading={isGenerating}
          />
        ) : null}
        
        {files.length === 0 || qrData ? (
          <GradientButton
            title={files.length === 0 ? "Select Files" : "Change Files"}
            onPress={handlePickFiles}
            variant="secondary"
          />
        ) : null}
      </View>
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
  emptyState: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: SPACING.xxl * 2,
  },
  emptyIconContainer: {
    width: 120,
    height: 120,
    borderRadius: 60,
    backgroundColor: COLORS.surface,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: SPACING.lg,
  },
  emptyTitle: {
    fontSize: 20,
    fontWeight: '700',
    color: COLORS.textPrimary,
    marginBottom: SPACING.sm,
  },
  emptyDescription: {
    fontSize: 14,
    color: COLORS.muted,
    textAlign: 'center',
    paddingHorizontal: SPACING.xl,
  },
  filesContainer: {
    marginTop: SPACING.lg,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '700',
    color: COLORS.textPrimary,
    marginBottom: SPACING.md,
  },
  qrSection: {
    marginTop: SPACING.xl,
    alignItems: 'center',
  },
  qrInstruction: {
    marginTop: SPACING.lg,
    fontSize: 14,
    color: COLORS.muted,
    textAlign: 'center',
    paddingHorizontal: SPACING.lg,
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
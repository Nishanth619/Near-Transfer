import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, SafeAreaView, TouchableOpacity, Alert } from 'react-native';
import { useRouter } from 'expo-router';
import { MaterialIcons } from '@expo/vector-icons';
import { Camera, CameraView } from 'expo-camera';
import Animated, { FadeIn, SlideInUp } from 'react-native-reanimated';
import { TransferManager } from '../src/services/webrtc/TransferManager';
import { GradientButton } from '../src/components/GradientButton';
import { useTransferStore } from '../src/store/transferStore';
import { COLORS, SPACING, RADIUS } from '../src/utils/constants';
import { decompressString } from '../src/utils/helpers';

export default function ReceiveScreen() {
  const router = useRouter();
  const [hasPermission, setHasPermission] = useState<boolean | null>(null);
  const [scanned, setScanned] = useState(false);
  const [isProcessing, setIsProcessing] = useState(false);
  const [transferManager] = useState(() => new TransferManager());

  const createSession = useTransferStore(state => state.createSession);
  const setError = useTransferStore(state => state.setError);

  useEffect(() => {
    (async () => {
      const { status } = await Camera.requestCameraPermissionsAsync();
      setHasPermission(status === 'granted');
    })();
  }, []);

  const handleBarCodeScanned = async ({ data }: { data: string }) => {
    if (scanned || isProcessing) return;

    setScanned(true);
    setIsProcessing(true);

    try {
      // Parse QR data
      const sessionData = JSON.parse(data);
      
      if (sessionData.type !== 'offer') {
        throw new Error('Invalid QR code');
      }

      // Decompress SDP
      const offerSdp = decompressString(sessionData.sdp);

      // Initialize as receiver and create answer
      const answerSdp = await transferManager.initializeAsReceiver(offerSdp);

      // In a real app, this answer would be sent back via:
      // 1. Display as QR for sender to scan
      // 2. Send through local network
      // 3. Use a temporary relay for signaling only

      // For now, create receive session and navigate
      createSession('receive', []);

      Alert.alert(
        'Connected!',
        `Ready to receive ${sessionData.fileCount} file(s)`,
        [
          {
            text: 'Start Transfer',
            onPress: () => {
              router.push({
                pathname: '/transfer',
                params: { type: 'receive' }
              });
            }
          }
        ]
      );

    } catch (error) {
      console.error('Error processing QR:', error);
      setError('Failed to establish connection');
      Alert.alert('Error', 'Invalid QR code or connection failed');
      setScanned(false);
    } finally {
      setIsProcessing(false);
    }
  };

  if (hasPermission === null) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.centerContainer}>
          <Text style={styles.messageText}>Requesting camera permission...</Text>
        </View>
      </SafeAreaView>
    );
  }

  if (hasPermission === false) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.centerContainer}>
          <MaterialIcons name="camera-alt" size={64} color={COLORS.muted} />
          <Text style={styles.messageTitle}>Camera Access Required</Text>
          <Text style={styles.messageText}>
            Please grant camera permission to scan QR codes
          </Text>
          <GradientButton
            title="Grant Permission"
            onPress={async () => {
              const { status } = await Camera.requestCameraPermissionsAsync();
              setHasPermission(status === 'granted');
            }}
            style={{ marginTop: SPACING.lg }}
          />
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <Animated.View entering={FadeIn.duration(600)} style={styles.header}>
        <TouchableOpacity onPress={() => router.back()} style={styles.backButton}>
          <MaterialIcons name="arrow-back" size={24} color={COLORS.surface} />
        </TouchableOpacity>
        <Text style={styles.title}>Receive Files</Text>
        <View style={styles.placeholder} />
      </Animated.View>

      <Animated.View entering={SlideInUp.delay(200)} style={styles.cameraContainer}>
        <CameraView
          style={styles.camera}
          onBarcodeScanned={scanned ? undefined : handleBarCodeScanned}
          barcodeScannerSettings={{
            barcodeTypes: ['qr'],
          }}
        >
          <View style={styles.overlay}>
            <View style={styles.scanArea}>
              <View style={[styles.corner, styles.topLeft]} />
              <View style={[styles.corner, styles.topRight]} />
              <View style={[styles.corner, styles.bottomLeft]} />
              <View style={[styles.corner, styles.bottomRight]} />
            </View>
          </View>
        </CameraView>
      </Animated.View>

      <Animated.View entering={FadeIn.delay(400)} style={styles.instructions}>
        <MaterialIcons name="qr-code-scanner" size={32} color={COLORS.accentStart} />
        <Text style={styles.instructionTitle}>
          {isProcessing ? 'Processing...' : 'Scan QR Code'}
        </Text>
        <Text style={styles.instructionText}>
          Align the QR code from the sender's device within the frame
        </Text>
      </Animated.View>

      {scanned && (
        <View style={styles.footer}>
          <GradientButton
            title="Scan Again"
            onPress={() => setScanned(false)}
            variant="secondary"
          />
        </View>
      )}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.textPrimary,
  },
  centerContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: SPACING.xl,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: SPACING.lg,
    paddingTop: SPACING.md,
    paddingBottom: SPACING.lg,
  },
  backButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: 'rgba(255, 255, 255, 0.2)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  title: {
    fontSize: 24,
    fontWeight: '700',
    color: COLORS.surface,
  },
  placeholder: {
    width: 40,
  },
  cameraContainer: {
    flex: 1,
    marginHorizontal: SPACING.lg,
    borderRadius: RADIUS.large,
    overflow: 'hidden',
    elevation: 8,
  },
  camera: {
    flex: 1,
  },
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  scanArea: {
    width: 280,
    height: 280,
    position: 'relative',
  },
  corner: {
    position: 'absolute',
    width: 40,
    height: 40,
    borderColor: COLORS.accentStart,
    borderWidth: 4,
  },
  topLeft: {
    top: 0,
    left: 0,
    borderRightWidth: 0,
    borderBottomWidth: 0,
    borderTopLeftRadius: RADIUS.base,
  },
  topRight: {
    top: 0,
    right: 0,
    borderLeftWidth: 0,
    borderBottomWidth: 0,
    borderTopRightRadius: RADIUS.base,
  },
  bottomLeft: {
    bottom: 0,
    left: 0,
    borderRightWidth: 0,
    borderTopWidth: 0,
    borderBottomLeftRadius: RADIUS.base,
  },
  bottomRight: {
    bottom: 0,
    right: 0,
    borderLeftWidth: 0,
    borderTopWidth: 0,
    borderBottomRightRadius: RADIUS.base,
  },
  instructions: {
    alignItems: 'center',
    paddingHorizontal: SPACING.xl,
    paddingVertical: SPACING.xl,
  },
  instructionTitle: {
    fontSize: 20,
    fontWeight: '700',
    color: COLORS.surface,
    marginTop: SPACING.md,
    marginBottom: SPACING.sm,
  },
  instructionText: {
    fontSize: 14,
    color: COLORS.surfaceAlt,
    textAlign: 'center',
  },
  messageTitle: {
    fontSize: 20,
    fontWeight: '700',
    color: COLORS.textPrimary,
    marginTop: SPACING.lg,
    marginBottom: SPACING.sm,
  },
  messageText: {
    fontSize: 14,
    color: COLORS.muted,
    textAlign: 'center',
  },
  footer: {
    padding: SPACING.lg,
  },
});
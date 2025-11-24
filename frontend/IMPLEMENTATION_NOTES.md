# NearTransfer Implementation Notes

## Current Status: MVP Demo ✅

### What's Working

✅ **Beautiful UI/UX**
- Industry-standard design with animations
- Smooth transitions between screens
- Glassmorphism effects and gradients
- Responsive layout for all screen sizes
- Touch-optimized interactions

✅ **Complete Navigation Flow**
- Home screen with Send/Receive options
- Send screen with file picker integration
- Receive screen with camera QR scanning
- Transfer progress screen with real-time updates
- State management with Zustand

✅ **File Handling**
- Multi-file selection using Expo Document Picker
- File metadata display (name, size, type)
- File type icons and visual cards
- Progress tracking per file

✅ **QR Code System**
- QR code generation with session data
- Countdown timer for QR expiry
- QR scanning with camera
- Session data compression

### What's Mocked (For Demo)

⚠️ **WebRTC Service**
- Current implementation is a mock for preview purposes
- Simulates connection establishment
- No actual P2P data transfer
- Ready structure for real WebRTC integration

## Production Implementation Guide

### Step 1: Install Native WebRTC

```bash
# Install react-native-webrtc
yarn add react-native-webrtc

# For Expo managed workflow, create development build
npx expo prebuild
npx expo run:ios
npx expo run:android
```

### Step 2: Configure Permissions

**app.json**:
```json
{
  "expo": {
    "plugins": [
      [
        "expo-camera",
        {
          "cameraPermission": "Allow NearTransfer to scan QR codes"
        }
      ],
      [
        "expo-document-picker",
        {
          "readStoragePermission": "Allow NearTransfer to access files"
        }
      ]
    ],
    "ios": {
      "infoPlist": {
        "NSCameraUsageDescription": "This app needs camera access to scan QR codes for file transfer",
        "NSPhotoLibraryUsageDescription": "This app needs access to your photos to send files"
      }
    },
    "android": {
      "permissions": [
        "android.permission.CAMERA",
        "android.permission.READ_EXTERNAL_STORAGE",
        "android.permission.WRITE_EXTERNAL_STORAGE",
        "android.permission.RECORD_AUDIO"
      ]
    }
  }
}
```

### Step 3: Implement Real WebRTC Service

Replace `/src/services/webrtc/WebRTCService.ts` with:

```typescript
import {
  RTCPeerConnection,
  RTCIceCandidate,
  RTCSessionDescription,
  mediaDevices,
} from 'react-native-webrtc';
import { STUN_SERVERS } from '../../utils/constants';

export class WebRTCService {
  private peerConnection: RTCPeerConnection | null = null;
  private dataChannel: any = null;
  private onDataCallback: ((data: any) => void) | null = null;
  private onConnectionStateCallback: ((state: string) => void) | null = null;

  async initialize(isInitiator: boolean = true): Promise<void> {
    const configuration = {
      iceServers: STUN_SERVERS,
    };

    this.peerConnection = new RTCPeerConnection(configuration);

    // Connection state monitoring
    this.peerConnection.onconnectionstatechange = () => {
      const state = this.peerConnection?.connectionState || 'disconnected';
      console.log('Connection state:', state);
      this.onConnectionStateCallback?.(state);
    };

    this.peerConnection.oniceconnectionstatechange = () => {
      const state = this.peerConnection?.iceConnectionState || 'disconnected';
      console.log('ICE Connection state:', state);
    };

    if (isInitiator) {
      // Create data channel for sender
      this.dataChannel = this.peerConnection.createDataChannel('fileTransfer', {
        ordered: true,
        maxRetransmits: 30,
      });
      this.setupDataChannelListeners();
    } else {
      // Listen for data channel on receiver
      this.peerConnection.ondatachannel = (event: any) => {
        this.dataChannel = event.channel;
        this.setupDataChannelListeners();
      };
    }
  }

  private setupDataChannelListeners(): void {
    if (!this.dataChannel) return;

    this.dataChannel.onopen = () => {
      console.log('Data channel opened');
      this.onConnectionStateCallback?.('connected');
    };

    this.dataChannel.onclose = () => {
      console.log('Data channel closed');
      this.onConnectionStateCallback?.('disconnected');
    };

    this.dataChannel.onmessage = (event: any) => {
      this.onDataCallback?.(event.data);
    };

    this.dataChannel.onerror = (error: any) => {
      console.error('Data channel error:', error);
      this.onConnectionStateCallback?.('failed');
    };
  }

  async createOffer(): Promise<string> {
    if (!this.peerConnection) throw new Error('Peer connection not initialized');

    const offer = await this.peerConnection.createOffer();
    await this.peerConnection.setLocalDescription(offer);

    // Wait for ICE gathering to complete
    await this.waitForIceGathering();

    return JSON.stringify(this.peerConnection.localDescription);
  }

  async createAnswer(offerSdp: string): Promise<string> {
    if (!this.peerConnection) throw new Error('Peer connection not initialized');

    const offer = JSON.parse(offerSdp);
    await this.peerConnection.setRemoteDescription(new RTCSessionDescription(offer));

    const answer = await this.peerConnection.createAnswer();
    await this.peerConnection.setLocalDescription(answer);

    // Wait for ICE gathering
    await this.waitForIceGathering();

    return JSON.stringify(this.peerConnection.localDescription);
  }

  async setAnswer(answerSdp: string): Promise<void> {
    if (!this.peerConnection) throw new Error('Peer connection not initialized');

    const answer = JSON.parse(answerSdp);
    await this.peerConnection.setRemoteDescription(new RTCSessionDescription(answer));
  }

  private waitForIceGathering(): Promise<void> {
    return new Promise((resolve) => {
      if (!this.peerConnection) {
        resolve();
        return;
      }

      if (this.peerConnection.iceGatheringState === 'complete') {
        resolve();
        return;
      }

      const checkState = () => {
        if (this.peerConnection?.iceGatheringState === 'complete') {
          this.peerConnection.removeEventListener('icegatheringstatechange', checkState);
          resolve();
        }
      };

      this.peerConnection.addEventListener('icegatheringstatechange', checkState);

      // Fallback timeout
      setTimeout(() => {
        this.peerConnection?.removeEventListener('icegatheringstatechange', checkState);
        resolve();
      }, 5000);
    });
  }

  sendData(data: any): void {
    if (this.dataChannel && this.dataChannel.readyState === 'open') {
      this.dataChannel.send(data);
    } else {
      throw new Error('Data channel is not open');
    }
  }

  onData(callback: (data: any) => void): void {
    this.onDataCallback = callback;
  }

  onConnectionStateChange(callback: (state: string) => void): void {
    this.onConnectionStateCallback = callback;
  }

  isConnected(): boolean {
    return this.dataChannel?.readyState === 'open';
  }

  getBufferedAmount(): number {
    return this.dataChannel?.bufferedAmount || 0;
  }

  close(): void {
    if (this.dataChannel) {
      this.dataChannel.close();
      this.dataChannel = null;
    }

    if (this.peerConnection) {
      this.peerConnection.close();
      this.peerConnection = null;
    }
  }
}
```

### Step 4: Answer Exchange Mechanism

For production, implement one of these patterns:

**Option A: Two-QR Handshake**
1. Sender displays offer QR
2. Receiver scans offer QR
3. Receiver generates answer QR
4. Sender scans answer QR
5. Connection established

**Option B: Local Network Discovery**
1. Use mDNS/Bonjour for device discovery
2. Exchange SDP over local TCP socket
3. No QR scanning needed on same network

**Option C: Temporary Signaling Server**
1. Use Firebase or simple WebSocket server
2. Generate 6-digit pairing code
3. Both devices connect to server with code
4. Exchange SDP through server
5. Server disconnected after handshake

### Step 5: Testing on Real Devices

1. **Build Development Apps**
   ```bash
   eas build --profile development --platform android
   eas build --profile development --platform ios
   ```

2. **Install on Two Devices**
   - Download and install APK/IPA
   - Grant all permissions

3. **Test Transfer**
   - Device A: Select files → Generate QR
   - Device B: Scan QR
   - Implement answer exchange
   - Start transfer
   - Verify files received

## Architecture Decisions

### Why Expo?
- Fast development and iteration
- Great developer experience
- Easy updates with EAS
- Can still use native modules with custom dev build

### Why Zustand?
- Lightweight (< 1KB)
- No boilerplate
- Perfect for small to medium state
- Easy to debug

### Why File-based Routing?
- Clean navigation structure
- Type-safe routes
- Automatic deep linking
- Easier to maintain

### Why WebRTC?
- True P2P (no server costs)
- Encrypted by default (DTLS)
- Works across networks (with STUN/TURN)
- Industry standard

## Performance Considerations

### Chunk Size
- 512KB default for good balance
- Smaller for slow connections
- Larger for fast local transfers

### Memory Management
- Stream file reading (don't load entire file)
- Clear chunks after sending
- Monitor buffer amount to prevent overflow

### Battery Optimization
- Use background services sparingly
- Implement transfer pause/resume
- Show persistent notification during transfer

## Security Notes

### What's Secure
✅ WebRTC DTLS encryption
✅ No cloud storage
✅ No server intermediary
✅ Local-only transfers

### What to Add
- Implement E2E encryption layer on top of DTLS
- Add file checksum verification (SHA-256)
- Implement transfer authentication (optional PIN)
- Add malware scanning integration

## Known Issues & Solutions

### Issue: Large QR Codes
**Solution**: Compress SDP with pako/gzip before encoding

### Issue: NAT Traversal
**Solution**: Add TURN server for relay (costs money)

### Issue: iOS Background Transfer
**Solution**: Use Background URLSession or VoIP push notifications

### Issue: Android Battery Restrictions
**Solution**: Request battery optimization exemption

## Next Steps

1. ✅ MVP UI/UX Complete
2. 🔄 Integrate real WebRTC
3. ⏳ Implement answer exchange
4. ⏳ Add transfer history
5. ⏳ Implement pause/resume
6. ⏳ Add background transfer
7. ⏳ Build native apps
8. ⏳ TestFlight/Play Store beta

---

**Bottom Line**: The UI/UX is production-ready. The WebRTC integration is straightforward but requires native build setup. The architecture is solid and scalable.
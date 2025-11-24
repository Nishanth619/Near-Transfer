import { STUN_SERVERS } from '../../utils/constants';

/**
 * WebRTC Service for P2P File Transfer
 * Note: This is a demo implementation. For production use with real devices:
 * 1. Install react-native-webrtc using: npx expo install react-native-webrtc
 * 2. Build a custom development client (won't work in Expo Go)
 * 3. Configure native permissions for iOS/Android
 */

export class WebRTCService {
  private peerConnection: any | null = null;
  private dataChannel: any = null;
  private onDataCallback: ((data: any) => void) | null = null;
  private onConnectionStateCallback: ((state: string) => void) | null = null;

  async initialize(isInitiator: boolean = true): Promise<void> {
    const configuration = {
      iceServers: STUN_SERVERS,
    };

    this.peerConnection = new RTCPeerConnection(configuration);

    // Set up connection state listener
    this.peerConnection.onconnectionstatechange = () => {
      const state = this.peerConnection?.connectionState || 'disconnected';
      console.log('Connection state:', state);
      this.onConnectionStateCallback?.(state);
    };

    // Set up ICE connection state listener
    this.peerConnection.oniceconnectionstatechange = () => {
      const state = this.peerConnection?.iceConnectionState || 'disconnected';
      console.log('ICE Connection state:', state);
    };

    if (isInitiator) {
      // Create data channel
      this.dataChannel = this.peerConnection.createDataChannel('fileTransfer', {
        ordered: true,
      });
      this.setupDataChannelListeners();
    } else {
      // Listen for data channel
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
    };

    this.dataChannel.onclose = () => {
      console.log('Data channel closed');
    };

    this.dataChannel.onmessage = (event: any) => {
      this.onDataCallback?.(event.data);
    };

    this.dataChannel.onerror = (error: any) => {
      console.error('Data channel error:', error);
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

    // Wait for ICE gathering to complete
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
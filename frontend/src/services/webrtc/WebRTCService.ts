import { STUN_SERVERS } from '../../utils/constants';

/**
 * WebRTC Service for P2P File Transfer
 * 
 * DEMO IMPLEMENTATION:
 * This is a simplified version to showcase the UI.
 * For production P2P transfers on real devices:
 * 1. Install: npx expo install react-native-webrtc
 * 2. Build custom development client (requires native code)
 * 3. Configure permissions in app.json
 * 4. Replace this mock with real WebRTC implementation
 */

export class WebRTCService {
  private dataChannel: any = null;
  private onDataCallback: ((data: any) => void) | null = null;
  private onConnectionStateCallback: ((state: string) => void) | null = null;
  private isInitialized = false;

  async initialize(isInitiator: boolean = true): Promise<void> {
    console.log('[WebRTC] Initializing as', isInitiator ? 'initiator' : 'receiver');
    
    // Simulate initialization delay
    await new Promise(resolve => setTimeout(resolve, 500));
    
    this.isInitialized = true;
    
    // Simulate connection established
    setTimeout(() => {
      this.onConnectionStateCallback?.('connected');
    }, 1000);
  }

  async createOffer(): Promise<string> {
    if (!this.isInitialized) throw new Error('Service not initialized');
    
    // Create mock SDP offer
    const mockOffer = {
      type: 'offer',
      sdp: 'v=0\no=- 123456789 2 IN IP4 127.0.0.1\ns=-\nt=0 0\na=group:BUNDLE 0\n...',
      timestamp: Date.now(),
    };
    
    return JSON.stringify(mockOffer);
  }

  async createAnswer(offerSdp: string): Promise<string> {
    if (!this.isInitialized) throw new Error('Service not initialized');
    
    // Create mock SDP answer
    const mockAnswer = {
      type: 'answer',
      sdp: 'v=0\no=- 987654321 2 IN IP4 127.0.0.1\ns=-\nt=0 0\na=group:BUNDLE 0\n...',
      timestamp: Date.now(),
    };
    
    return JSON.stringify(mockAnswer);
  }

  async setAnswer(answerSdp: string): Promise<void> {
    console.log('[WebRTC] Answer set successfully');
  }

  sendData(data: any): void {
    if (!this.isInitialized) {
      throw new Error('Data channel is not open');
    }
    
    // In a real implementation, this would send data through WebRTC
    console.log('[WebRTC] Sending data:', typeof data);
  }

  onData(callback: (data: any) => void): void {
    this.onDataCallback = callback;
  }

  onConnectionStateChange(callback: (state: string) => void): void {
    this.onConnectionStateCallback = callback;
  }

  isConnected(): boolean {
    return this.isInitialized;
  }

  getBufferedAmount(): number {
    return 0;
  }

  close(): void {
    this.isInitialized = false;
    this.dataChannel = null;
    console.log('[WebRTC] Connection closed');
  }
}

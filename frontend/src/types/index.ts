export interface FileItem {
  id: string;
  name: string;
  size: number;
  uri: string;
  mimeType?: string;
  progress: number;
  status: 'pending' | 'transferring' | 'completed' | 'failed' | 'paused';
  speed?: number;
  eta?: number;
}

export interface TransferSession {
  id: string;
  type: 'send' | 'receive';
  files: FileItem[];
  peerId?: string;
  status: 'idle' | 'connecting' | 'connected' | 'transferring' | 'completed' | 'failed';
  totalSize: number;
  transferredSize: number;
  startTime?: number;
  endTime?: number;
}

export interface ConnectionInfo {
  sessionId: string;
  offer?: string;
  answer?: string;
  timestamp: number;
}
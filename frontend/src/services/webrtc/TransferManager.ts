import { WebRTCService } from './WebRTCService';
import { FileService } from '../file/FileService';
import { FileItem } from '../../types';
import { CHUNK_SIZE, MAX_BUFFER_SIZE } from '../../utils/constants';

interface TransferMetadata {
  fileId: string;
  fileName: string;
  fileSize: number;
  totalChunks: number;
  mimeType?: string;
}

interface ChunkData {
  fileId: string;
  chunkIndex: number;
  data: string;
  isLast: boolean;
}

export class TransferManager {
  private webrtc: WebRTCService;
  private fileService: FileService;
  private onProgressCallback: ((fileId: string, progress: number, speed: number) => void) | null = null;
  private onFileCompleteCallback: ((fileId: string, uri: string) => void) | null = null;
  private receivingFiles: Map<string, { metadata: TransferMetadata; chunks: string[]; receivedChunks: number }> = new Map();
  private isSending = false;

  constructor() {
    this.webrtc = new WebRTCService();
    this.fileService = new FileService();
  }

  async initializeAsSender(): Promise<string> {
    await this.webrtc.initialize(true);
    this.setupDataListener();
    return await this.webrtc.createOffer();
  }

  async initializeAsReceiver(offerSdp: string): Promise<string> {
    await this.webrtc.initialize(false);
    this.setupDataListener();
    return await this.webrtc.createAnswer(offerSdp);
  }

  async completeConnection(answerSdp: string): Promise<void> {
    await this.webrtc.setAnswer(answerSdp);
  }

  private setupDataListener(): void {
    this.webrtc.onData((data: string) => {
      try {
        const message = JSON.parse(data);

        if (message.type === 'metadata') {
          this.handleMetadata(message.data);
        } else if (message.type === 'chunk') {
          this.handleChunk(message.data);
        } else if (message.type === 'ack') {
          // Handle acknowledgment
          console.log('Received ACK for chunk:', message.chunkIndex);
        }
      } catch (error) {
        console.error('Error processing received data:', error);
      }
    });
  }

  private handleMetadata(metadata: TransferMetadata): void {
    console.log('Received file metadata:', metadata);
    this.receivingFiles.set(metadata.fileId, {
      metadata,
      chunks: new Array(metadata.totalChunks).fill(''),
      receivedChunks: 0,
    });

    // Send acknowledgment
    this.sendMessage({ type: 'metadata_ack', fileId: metadata.fileId });
  }

  private async handleChunk(chunk: ChunkData): Promise<void> {
    const fileData = this.receivingFiles.get(chunk.fileId);
    if (!fileData) {
      console.error('Received chunk for unknown file:', chunk.fileId);
      return;
    }

    // Store chunk
    fileData.chunks[chunk.chunkIndex] = chunk.data;
    fileData.receivedChunks++;

    // Calculate progress
    const progress = (fileData.receivedChunks / fileData.metadata.totalChunks) * 100;
    this.onProgressCallback?.(chunk.fileId, progress, 0);

    // Send acknowledgment
    this.sendMessage({ type: 'ack', fileId: chunk.fileId, chunkIndex: chunk.chunkIndex });

    // If last chunk, save file
    if (chunk.isLast || fileData.receivedChunks === fileData.metadata.totalChunks) {
      await this.saveReceivedFile(chunk.fileId);
    }
  }

  private async saveReceivedFile(fileId: string): Promise<void> {
    const fileData = this.receivingFiles.get(fileId);
    if (!fileData) return;

    try {
      // Combine all chunks
      const completeData = fileData.chunks.join('');

      // Create file path
      const filePath = await this.fileService.createDownloadPath(fileData.metadata.fileName);

      // Write file
      await this.fileService.writeFileChunk(filePath, completeData, false);

      console.log('File saved successfully:', filePath);
      this.onFileCompleteCallback?.(fileId, filePath);

      // Clean up
      this.receivingFiles.delete(fileId);
    } catch (error) {
      console.error('Error saving received file:', error);
    }
  }

  async sendFiles(files: FileItem[]): Promise<void> {
    if (this.isSending) {
      throw new Error('Already sending files');
    }

    this.isSending = true;

    try {
      for (const file of files) {
        await this.sendFile(file);
      }
    } finally {
      this.isSending = false;
    }
  }

  private async sendFile(file: FileItem): Promise<void> {
    const totalChunks = Math.ceil(file.size / CHUNK_SIZE);

    // Send metadata
    const metadata: TransferMetadata = {
      fileId: file.id,
      fileName: file.name,
      fileSize: file.size,
      totalChunks,
      mimeType: file.mimeType,
    };

    this.sendMessage({ type: 'metadata', data: metadata });

    // Wait a bit for metadata acknowledgment
    await new Promise(resolve => setTimeout(resolve, 100));

    // Send chunks
    const startTime = Date.now();
    let sentBytes = 0;

    for (let i = 0; i < totalChunks; i++) {
      const start = i * CHUNK_SIZE;
      const end = Math.min(start + CHUNK_SIZE, file.size);

      // Read chunk
      const chunkData = await this.fileService.readFileChunk(file.uri, start, end);

      // Wait if buffer is too full
      while (this.webrtc.getBufferedAmount() > MAX_BUFFER_SIZE) {
        await new Promise(resolve => setTimeout(resolve, 50));
      }

      // Send chunk
      const chunk: ChunkData = {
        fileId: file.id,
        chunkIndex: i,
        data: chunkData,
        isLast: i === totalChunks - 1,
      };

      this.sendMessage({ type: 'chunk', data: chunk });

      // Update progress
      sentBytes += (end - start);
      const progress = (sentBytes / file.size) * 100;
      const elapsed = (Date.now() - startTime) / 1000;
      const speed = sentBytes / elapsed;

      this.onProgressCallback?.(file.id, progress, speed);

      // Small delay between chunks
      await new Promise(resolve => setTimeout(resolve, 10));
    }

    console.log('File sent successfully:', file.name);
  }

  private sendMessage(message: any): void {
    try {
      this.webrtc.sendData(JSON.stringify(message));
    } catch (error) {
      console.error('Error sending message:', error);
    }
  }

  onProgress(callback: (fileId: string, progress: number, speed: number) => void): void {
    this.onProgressCallback = callback;
  }

  onFileComplete(callback: (fileId: string, uri: string) => void): void {
    this.onFileCompleteCallback = callback;
  }

  onConnectionStateChange(callback: (state: string) => void): void {
    this.webrtc.onConnectionStateChange(callback);
  }

  isConnected(): boolean {
    return this.webrtc.isConnected();
  }

  close(): void {
    this.webrtc.close();
    this.receivingFiles.clear();
    this.isSending = false;
  }

  getWebRTCService(): WebRTCService {
    return this.webrtc;
  }
}
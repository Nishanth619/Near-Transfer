import * as FileSystem from 'expo-file-system';
import * as DocumentPicker from 'expo-document-picker';
import { FileItem } from '../../types';
import { generateId } from '../../utils/helpers';

export class FileService {
  async pickFiles(): Promise<FileItem[]> {
    try {
      const result = await DocumentPicker.getDocumentAsync({
        type: '*/*',
        multiple: true,
        copyToCacheDirectory: false,
      });

      if (result.canceled) {
        return [];
      }

      return result.assets.map(asset => ({
        id: generateId(),
        name: asset.name,
        size: asset.size || 0,
        uri: asset.uri,
        mimeType: asset.mimeType || 'application/octet-stream',
        progress: 0,
        status: 'pending' as const,
      }));
    } catch (error) {
      console.error('Error picking files:', error);
      throw error;
    }
  }

  async readFileChunk(uri: string, start: number, end: number): Promise<string> {
    try {
      // Read file as base64
      const content = await FileSystem.readAsStringAsync(uri, {
        encoding: FileSystem.EncodingType.Base64,
      });

      // Calculate chunk positions in base64
      const chunkStart = Math.floor((start / 3) * 4);
      const chunkEnd = Math.ceil((end / 3) * 4);

      return content.substring(chunkStart, chunkEnd);
    } catch (error) {
      console.error('Error reading file chunk:', error);
      throw error;
    }
  }

  async writeFileChunk(uri: string, data: string, append: boolean = true): Promise<void> {
    try {
      if (append) {
        await FileSystem.writeAsStringAsync(uri, data, {
          encoding: FileSystem.EncodingType.Base64,
        });
      } else {
        await FileSystem.writeAsStringAsync(uri, data, {
          encoding: FileSystem.EncodingType.Base64,
        });
      }
    } catch (error) {
      console.error('Error writing file chunk:', error);
      throw error;
    }
  }

  async createDownloadPath(filename: string): Promise<string> {
    const downloadDir = FileSystem.documentDirectory + 'NearTransfer/';
    
    // Create directory if it doesn't exist
    const dirInfo = await FileSystem.getInfoAsync(downloadDir);
    if (!dirInfo.exists) {
      await FileSystem.makeDirectoryAsync(downloadDir, { intermediates: true });
    }

    return downloadDir + filename;
  }

  async getFileInfo(uri: string) {
    try {
      return await FileSystem.getInfoAsync(uri);
    } catch (error) {
      console.error('Error getting file info:', error);
      return null;
    }
  }

  async deleteFile(uri: string): Promise<void> {
    try {
      await FileSystem.deleteAsync(uri, { idempotent: true });
    } catch (error) {
      console.error('Error deleting file:', error);
    }
  }
}
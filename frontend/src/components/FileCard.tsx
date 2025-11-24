import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import * as Progress from 'react-native-progress';
import { FileItem } from '../types';
import { COLORS, RADIUS, SPACING } from '../utils/constants';
import { formatBytes, formatSpeed } from '../utils/helpers';

interface FileCardProps {
  file: FileItem;
}

export const FileCard: React.FC<FileCardProps> = ({ file }) => {
  const getFileIcon = (name: string) => {
    const ext = name.split('.').pop()?.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'picture-as-pdf';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return 'image';
      case 'mp4':
      case 'mov':
      case 'avi':
        return 'video-library';
      case 'mp3':
      case 'wav':
        return 'audiotrack';
      case 'zip':
      case 'rar':
        return 'folder-zip';
      default:
        return 'insert-drive-file';
    }
  };

  const getStatusColor = () => {
    switch (file.status) {
      case 'completed':
        return COLORS.success;
      case 'failed':
        return COLORS.danger;
      case 'transferring':
        return COLORS.accentStart;
      default:
        return COLORS.muted;
    }
  };

  return (
    <View style={styles.container}>
      <View style={styles.iconContainer}>
        <MaterialIcons name={getFileIcon(file.name)} size={32} color={COLORS.primary} />
      </View>
      
      <View style={styles.content}>
        <Text style={styles.fileName} numberOfLines={1}>
          {file.name}
        </Text>
        <Text style={styles.fileSize}>{formatBytes(file.size)}</Text>
        
        {file.status !== 'pending' && (
          <View style={styles.progressContainer}>
            <Progress.Bar
              progress={file.progress / 100}
              width={null}
              height={6}
              color={getStatusColor()}
              unfilledColor={COLORS.surfaceAlt}
              borderWidth={0}
              borderRadius={3}
            />
            <View style={styles.progressInfo}>
              <Text style={styles.progressText}>{Math.round(file.progress)}%</Text>
              {file.speed && file.status === 'transferring' && (
                <Text style={styles.speedText}>{formatSpeed(file.speed)}</Text>
              )}
            </View>
          </View>
        )}
      </View>

      <View style={[styles.statusBadge, { backgroundColor: getStatusColor() }]}>
        <MaterialIcons 
          name={file.status === 'completed' ? 'check' : file.status === 'failed' ? 'close' : 'sync'} 
          size={16} 
          color={COLORS.surface} 
        />
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.surface,
    borderRadius: RADIUS.base,
    padding: SPACING.md,
    marginBottom: SPACING.md,
    elevation: 2,
    shadowColor: COLORS.textPrimary,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
  },
  iconContainer: {
    width: 48,
    height: 48,
    borderRadius: RADIUS.base,
    backgroundColor: COLORS.surfaceAlt,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: SPACING.md,
  },
  content: {
    flex: 1,
  },
  fileName: {
    fontSize: 16,
    fontWeight: '600',
    color: COLORS.textPrimary,
    marginBottom: 4,
  },
  fileSize: {
    fontSize: 14,
    color: COLORS.muted,
    marginBottom: 8,
  },
  progressContainer: {
    marginTop: 8,
  },
  progressInfo: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 4,
  },
  progressText: {
    fontSize: 12,
    fontWeight: '600',
    color: COLORS.textPrimary,
  },
  speedText: {
    fontSize: 12,
    color: COLORS.muted,
  },
  statusBadge: {
    width: 28,
    height: 28,
    borderRadius: 14,
    justifyContent: 'center',
    alignItems: 'center',
    marginLeft: SPACING.sm,
  },
});
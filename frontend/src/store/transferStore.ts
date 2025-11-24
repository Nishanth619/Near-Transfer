import { create } from 'zustand';
import { FileItem, TransferSession } from '../types';

interface TransferState {
  currentSession: TransferSession | null;
  history: TransferSession[];
  isConnecting: boolean;
  error: string | null;
  
  // Actions
  createSession: (type: 'send' | 'receive', files?: FileItem[]) => void;
  updateSession: (updates: Partial<TransferSession>) => void;
  updateFileProgress: (fileId: string, progress: number, speed?: number) => void;
  setConnecting: (connecting: boolean) => void;
  setError: (error: string | null) => void;
  completeSession: () => void;
  resetSession: () => void;
}

export const useTransferStore = create<TransferState>((set, get) => ({
  currentSession: null,
  history: [],
  isConnecting: false,
  error: null,

  createSession: (type, files = []) => {
    const session: TransferSession = {
      id: `session-${Date.now()}`,
      type,
      files,
      status: 'idle',
      totalSize: files.reduce((sum, f) => sum + f.size, 0),
      transferredSize: 0,
      startTime: Date.now(),
    };
    set({ currentSession: session, error: null });
  },

  updateSession: (updates) => {
    const current = get().currentSession;
    if (current) {
      set({ currentSession: { ...current, ...updates } });
    }
  },

  updateFileProgress: (fileId, progress, speed) => {
    const current = get().currentSession;
    if (!current) return;

    const updatedFiles = current.files.map(file => {
      if (file.id === fileId) {
        return { ...file, progress, speed, status: progress === 100 ? 'completed' : 'transferring' };
      }
      return file;
    });

    const transferredSize = updatedFiles.reduce((sum, f) => sum + (f.size * f.progress / 100), 0);

    set({
      currentSession: {
        ...current,
        files: updatedFiles,
        transferredSize,
      },
    });
  },

  setConnecting: (connecting) => set({ isConnecting: connecting }),

  setError: (error) => set({ error }),

  completeSession: () => {
    const current = get().currentSession;
    if (current) {
      const completedSession = {
        ...current,
        status: 'completed' as const,
        endTime: Date.now(),
      };
      set({
        currentSession: null,
        history: [completedSession, ...get().history],
      });
    }
  },

  resetSession: () => {
    set({ currentSession: null, error: null, isConnecting: false });
  },
}));
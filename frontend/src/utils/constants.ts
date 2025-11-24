export const COLORS = {
  primary: '#27357B',
  accentStart: '#00BFA6',
  accentEnd: '#00E5FF',
  surface: '#FFFFFF',
  surfaceAlt: '#F6F7FB',
  textPrimary: '#0F1724',
  muted: '#6B7280',
  success: '#16A34A',
  danger: '#DC2626',
  backdrop: 'rgba(15, 23, 36, 0.5)',
};

export const RADIUS = {
  base: 14,
  large: 20,
  full: 9999,
};

export const SPACING = {
  xs: 4,
  sm: 8,
  md: 16,
  lg: 24,
  xl: 32,
  xxl: 48,
};

export const BUTTON_HEIGHT = 56;

export const CHUNK_SIZE = 512 * 1024; // 512KB
export const MAX_BUFFER_SIZE = 16 * 1024 * 1024; // 16MB

export const STUN_SERVERS = [
  { urls: 'stun:stun.l.google.com:19302' },
  { urls: 'stun:stun1.l.google.com:19302' },
];
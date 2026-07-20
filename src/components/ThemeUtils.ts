import React from 'react';
import { TagColor } from '../types';
import { cn } from '../utils';

export const getTagColorClasses = (color: TagColor, isDark: boolean) => {
  switch (color) {
    case 'coral': return isDark ? 'bg-coral/20 text-coral' : 'bg-coral/10 text-coral';
    case 'amber': return isDark ? 'bg-amber/20 text-amber' : 'bg-amber/10 text-amber';
    case 'sage': return isDark ? 'bg-sage/20 text-sage' : 'bg-sage/10 text-sage';
    case 'ink-blue': return isDark ? 'bg-ink-blue/20 text-ink-blue' : 'bg-ink-blue/10 text-ink-blue';
    default: return 'bg-gray-500/20 text-gray-500';
  }
};

export const getTagDotColor = (color: TagColor) => {
  switch (color) {
    case 'coral': return 'bg-coral';
    case 'amber': return 'bg-amber';
    case 'sage': return 'bg-sage';
    case 'ink-blue': return 'bg-ink-blue';
    default: return 'bg-gray-500';
  }
};

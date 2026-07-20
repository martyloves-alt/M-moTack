export type TagColor = 'coral' | 'amber' | 'sage' | 'ink-blue';

export type Tag = {
  id: string;
  name: string;
  color: TagColor;
};

export type Flashcard = {
  id: string;
  front: string;
  back: string;
  tagId: string;
  level: number;
  nextReview: number;
  createdAt: number;
};

export type Settings = {
  remindersPerDay: number;
  activeHoursStart: string;
  activeHoursEnd: string;
  theme: 'light' | 'dark';
};

export type ViewState = 'dashboard' | 'add' | 'settings';

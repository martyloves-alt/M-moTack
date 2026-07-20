import { Tag, Flashcard, Settings } from './types';

export const INITIAL_TAGS: Tag[] = [
  { id: 't1', name: 'Médical', color: 'sauge' as any }, // Will map to sage/coral in UI
  { id: 't2', name: 'Perso', color: 'coral' },
  { id: 't3', name: 'Réseaux sociaux', color: 'amber' },
];

// Re-map 'sauge' to 'sage' since the prompt asked for "Sauge"
INITIAL_TAGS[0].color = 'sage';

const now = Date.now();
const ONE_HOUR = 60 * 60 * 1000;

export const INITIAL_FLASHCARDS: Flashcard[] = [
  {
    id: 'f1',
    front: 'Anasarque',
    back: 'Œdème généralisé sous-cutané et des séreuses',
    tagId: 't1',
    level: 0,
    nextReview: now - ONE_HOUR, // Due now
    createdAt: now - ONE_HOUR * 24,
  },
  {
    id: 'f2',
    front: 'Nomogramme de Bhutani',
    back: 'Courbe de référence pour la photothérapie néonatale',
    tagId: 't1',
    level: 1,
    nextReview: now + ONE_HOUR * 2, // Due later
    createdAt: now - ONE_HOUR * 48,
  },
  {
    id: 'f3',
    front: 'Respire avant de répondre',
    back: 'Rappel perso pour les situations de stress',
    tagId: 't2',
    level: 0,
    nextReview: now - ONE_HOUR * 2, // Due now
    createdAt: now - ONE_HOUR * 72,
  },
  {
    id: 'f4',
    front: 'Hook narratif',
    back: 'Les 3 premières secondes qui retiennent le spectateur',
    tagId: 't3',
    level: 2,
    nextReview: now + ONE_HOUR * 24, // Due tomorrow
    createdAt: now - ONE_HOUR * 120,
  },
];

export const INITIAL_SETTINGS: Settings = {
  remindersPerDay: 4,
  activeHoursStart: '08:00',
  activeHoursEnd: '23:00',
  theme: 'dark',
};

// SRS Intervals based on level (in hours)
export const SRS_INTERVALS = [
  1,     // Level 0: 1 hour
  4,     // Level 1: 4 hours
  12,    // Level 2: 12 hours
  24,    // Level 3: 1 day
  72,    // Level 4: 3 days
  168,   // Level 5: 1 week
];

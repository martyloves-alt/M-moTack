import React, { createContext, useContext, useEffect, useState } from 'react';
import { Flashcard, Settings, Tag, ViewState } from './types';
import { INITIAL_FLASHCARDS, INITIAL_SETTINGS, INITIAL_TAGS, SRS_INTERVALS } from './data';

type AppContextType = {
  view: ViewState;
  setView: (view: ViewState) => void;
  flashcards: Flashcard[];
  tags: Tag[];
  settings: Settings;
  addFlashcard: (card: Omit<Flashcard, 'id' | 'createdAt' | 'level' | 'nextReview'>) => void;
  reviewCard: (id: string, remembered: boolean) => void;
  updateSettings: (newSettings: Partial<Settings>) => void;
};

const AppContext = createContext<AppContextType | undefined>(undefined);

export const AppProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [view, setView] = useState<ViewState>('dashboard');
  
  const [flashcards, setFlashcards] = useState<Flashcard[]>(() => {
    const saved = localStorage.getItem('memotack_cards');
    return saved ? JSON.parse(saved) : INITIAL_FLASHCARDS;
  });

  const [tags] = useState<Tag[]>(() => {
    const saved = localStorage.getItem('memotack_tags');
    return saved ? JSON.parse(saved) : INITIAL_TAGS;
  });

  const [settings, setSettings] = useState<Settings>(() => {
    const saved = localStorage.getItem('memotack_settings');
    return saved ? JSON.parse(saved) : INITIAL_SETTINGS;
  });

  useEffect(() => {
    localStorage.setItem('memotack_cards', JSON.stringify(flashcards));
  }, [flashcards]);

  useEffect(() => {
    localStorage.setItem('memotack_tags', JSON.stringify(tags));
  }, [tags]);

  useEffect(() => {
    localStorage.setItem('memotack_settings', JSON.stringify(settings));
    // Apply theme
    if (settings.theme === 'dark') {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  }, [settings]);

  const addFlashcard = (card: Omit<Flashcard, 'id' | 'createdAt' | 'level' | 'nextReview'>) => {
    const newCard: Flashcard = {
      ...card,
      id: Math.random().toString(36).substring(2, 9),
      createdAt: Date.now(),
      level: 0,
      nextReview: Date.now() + SRS_INTERVALS[0] * 60 * 60 * 1000,
    };
    setFlashcards(prev => [...prev, newCard]);
    setView('dashboard');
  };

  const reviewCard = (id: string, remembered: boolean) => {
    setFlashcards(prev => prev.map(card => {
      if (card.id === id) {
        let newLevel = card.level;
        if (remembered) {
          newLevel = Math.min(newLevel + 1, SRS_INTERVALS.length - 1);
        } else {
          newLevel = Math.max(0, newLevel - 1);
        }
        
        const hoursToAdd = SRS_INTERVALS[newLevel];
        const nextReview = Date.now() + hoursToAdd * 60 * 60 * 1000;
        
        return { ...card, level: newLevel, nextReview };
      }
      return card;
    }));
  };

  const updateSettings = (newSettings: Partial<Settings>) => {
    setSettings(prev => ({ ...prev, ...newSettings }));
  };

  return (
    <AppContext.Provider value={{
      view, setView, flashcards, tags, settings, addFlashcard, reviewCard, updateSettings
    }}>
      {children}
    </AppContext.Provider>
  );
};

export const useAppContext = () => {
  const context = useContext(AppContext);
  if (!context) throw new Error("useAppContext must be used within AppProvider");
  return context;
};

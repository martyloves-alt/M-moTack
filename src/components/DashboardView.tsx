import React, { useMemo } from 'react';
import { useAppContext } from '../context';
import FlashcardItem from './FlashcardItem';
import { isPast } from 'date-fns';
import { motion } from 'framer-motion';

export default function DashboardView() {
  const { flashcards } = useAppContext();

  const dueCards = useMemo(() => 
    flashcards.filter(c => isPast(c.nextReview)).sort((a, b) => a.nextReview - b.nextReview),
  [flashcards]);

  const upcomingCards = useMemo(() => 
    flashcards.filter(c => !isPast(c.nextReview)).sort((a, b) => a.nextReview - b.nextReview),
  [flashcards]);

  const container = {
    hidden: { opacity: 0 },
    show: {
      opacity: 1,
      transition: { staggerChildren: 0.1 }
    }
  };

  const item = {
    hidden: { opacity: 0, y: 10 },
    show: { opacity: 1, y: 0, transition: { type: "spring", stiffness: 300, damping: 24 } }
  };

  return (
    <div className="space-y-10 pb-10">
      
      <section>
        <div className="flex items-baseline justify-between mb-6">
          <h1 className="font-serif text-3xl font-light tracking-tight">Aujourd'hui</h1>
          <span className="font-mono text-xs uppercase tracking-widest text-paper-muted">
            {dueCards.length} carte{dueCards.length !== 1 ? 's' : ''}
          </span>
        </div>
        
        {dueCards.length === 0 ? (
          <div className="py-12 flex flex-col items-center justify-center border border-dashed border-paper-muted/30 rounded-xl">
            <p className="font-serif text-lg text-paper-muted mb-2 text-center">Vous êtes à jour.</p>
            <p className="font-sans text-sm text-paper-muted/70 text-center">Prenez un moment pour respirer.</p>
          </div>
        ) : (
          <motion.div variants={container} initial="hidden" animate="show" className="space-y-4">
            {dueCards.map(card => (
              <motion.div key={card.id} layout variants={item}>
                <FlashcardItem card={card} />
              </motion.div>
            ))}
          </motion.div>
        )}
      </section>

      {upcomingCards.length > 0 && (
        <section>
          <div className="flex items-baseline justify-between mb-6">
            <h2 className="font-serif text-2xl font-light tracking-tight text-paper-muted">À venir</h2>
            <span className="font-mono text-xs uppercase tracking-widest text-paper-muted/60">
              {upcomingCards.length} carte{upcomingCards.length !== 1 ? 's' : ''}
            </span>
          </div>
          <div className="space-y-4 opacity-70 hover:opacity-100 transition-opacity duration-300">
            {upcomingCards.map(card => (
              <div key={card.id}>
                <FlashcardItem card={card} />
              </div>
            ))}
          </div>
        </section>
      )}

    </div>
  );
}

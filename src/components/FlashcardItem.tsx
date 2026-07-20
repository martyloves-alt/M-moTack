import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Flashcard } from '../types';
import { useAppContext } from '../context';
import { getTagDotColor, getTagColorClasses } from './ThemeUtils';
import { cn } from '../utils';
import { formatDistanceToNow, isPast } from 'date-fns';
import { fr } from 'date-fns/locale';

export default function FlashcardItem({ card, isPreview = false }: { card: Flashcard, isPreview?: boolean }) {
  const { tags, reviewCard, settings } = useAppContext();
  const [isFlipped, setIsFlipped] = useState(false);
  const tag = tags.find(t => t.id === card.tagId) || tags[0];
  const isDark = settings.theme === 'dark';
  
  const isDue = isPast(card.nextReview);

  const handleReview = (e: React.MouseEvent, remembered: boolean) => {
    e.stopPropagation();
    reviewCard(card.id, remembered);
    setIsFlipped(false);
  };

  return (
    <motion.div
      layout
      onClick={() => !isPreview && setIsFlipped(!isFlipped)}
      className={cn(
        "relative w-full rounded-xl overflow-hidden cursor-pointer",
        isDark ? "bg-ink-light shadow-md shadow-black/20" : "bg-white shadow-sm border border-paper-muted/30"
      )}
    >
      <div className="p-5 flex flex-col h-full min-h-[120px]">
        
        {/* Header: Tag + Level/Time */}
        <div className="flex justify-between items-center mb-4">
          <div className="flex items-center space-x-2">
            <span className={cn("w-2.5 h-2.5 rounded-full shadow-inner", getTagDotColor(tag.color))} />
            <span className={cn(
              "text-xs font-mono tracking-widest uppercase font-medium px-2 py-0.5 rounded-full",
              getTagColorClasses(tag.color, isDark)
            )}>
              {tag.name}
            </span>
          </div>
          
          {!isPreview && (
            <div className="text-[10px] font-mono tracking-widest uppercase text-paper-muted flex items-center space-x-2">
              <span>Lvl {card.level}</span>
              <span>•</span>
              <span className={isDue && !isFlipped ? "text-coral" : ""}>
                {isDue ? "Dû" : formatDistanceToNow(card.nextReview, { locale: fr, addSuffix: true })}
              </span>
            </div>
          )}
        </div>

        {/* Content */}
        <div className="flex-1 flex flex-col justify-center">
          <h3 className={cn(
            "font-serif text-xl sm:text-2xl leading-snug tracking-tight mb-2",
            isDark ? "text-paper" : "text-soot"
          )}>
            {card.front}
          </h3>

          <AnimatePresence initial={false}>
            {(isFlipped || isPreview) && card.back && (
              <motion.div
                initial={{ opacity: 0, height: 0 }}
                animate={{ opacity: 1, height: 'auto' }}
                exit={{ opacity: 0, height: 0 }}
                transition={{ duration: 0.3, ease: "easeInOut" }}
                className="overflow-hidden"
              >
                <div className="pt-3 mt-3 border-t border-paper-muted/20">
                  <p className={cn(
                    "font-sans text-sm leading-relaxed",
                    isDark ? "text-paper-muted" : "text-soot/80"
                  )}>
                    {card.back}
                  </p>
                </div>
              </motion.div>
            )}
          </AnimatePresence>
        </div>

        {/* Action Buttons */}
        <AnimatePresence initial={false}>
          {isFlipped && !isPreview && (
            <motion.div
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: 10 }}
              className="mt-6 flex space-x-3 pt-4 border-t border-paper-muted/20"
            >
              <button
                onClick={(e) => handleReview(e, false)}
                className="flex-1 py-2.5 rounded-lg font-mono text-xs tracking-wider uppercase font-medium bg-paper-muted/20 text-paper-muted hover:bg-coral/20 hover:text-coral transition-colors"
              >
                Oublié
              </button>
              <button
                onClick={(e) => handleReview(e, true)}
                className={cn(
                  "flex-1 py-2.5 rounded-lg font-mono text-xs tracking-wider uppercase font-medium transition-colors",
                  isDark ? "bg-paper text-ink hover:bg-paper/90" : "bg-soot text-paper hover:bg-soot/90"
                )}
              >
                Je le savais
              </button>
            </motion.div>
          )}
        </AnimatePresence>
        
      </div>
    </motion.div>
  );
}

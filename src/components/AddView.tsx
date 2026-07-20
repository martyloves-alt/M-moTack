import React, { useState } from 'react';
import { useAppContext } from '../context';
import FlashcardItem from './FlashcardItem';
import { cn } from '../utils';
import { getTagColorClasses } from './ThemeUtils';

export default function AddView() {
  const { tags, addFlashcard, settings } = useAppContext();
  const isDark = settings.theme === 'dark';

  const [front, setFront] = useState('');
  const [back, setBack] = useState('');
  const [selectedTagId, setSelectedTagId] = useState(tags[0]?.id);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!front.trim()) return;
    addFlashcard({ front: front.trim(), back: back.trim(), tagId: selectedTagId });
    setFront('');
    setBack('');
  };

  const previewCard = {
    id: 'preview',
    front: front || 'Nouveau mot ou phrase',
    back: back,
    tagId: selectedTagId,
    level: 0,
    nextReview: Date.now(),
    createdAt: Date.now(),
  };

  return (
    <div className="space-y-8 pb-10">
      <div>
        <h1 className="font-serif text-3xl font-light tracking-tight mb-2">Ajouter</h1>
        <p className="font-sans text-sm text-paper-muted">Créez une nouvelle carte pour votre apprentissage.</p>
      </div>

      <form onSubmit={handleSubmit} className="space-y-6">
        
        {/* Front Input */}
        <div className="space-y-2">
          <div className="flex justify-between items-baseline">
            <label htmlFor="front" className="font-mono text-xs tracking-widest uppercase text-paper-muted">
              Mot ou phrase
            </label>
            <span className={cn(
              "font-mono text-[10px] tracking-wider",
              front.length > 150 ? "text-coral" : "text-paper-muted/60"
            )}>
              {front.length}/150
            </span>
          </div>
          <textarea
            id="front"
            value={front}
            onChange={(e) => setFront(e.target.value.slice(0, 150))}
            placeholder="Ex: Anasarque"
            className={cn(
              "w-full rounded-xl p-4 font-serif text-xl resize-none outline-none transition-shadow",
              isDark 
                ? "bg-ink-light text-paper placeholder-paper-muted/30 focus:ring-1 focus:ring-paper/30" 
                : "bg-white text-soot border border-paper-muted/30 placeholder-paper-muted/50 focus:ring-1 focus:ring-soot/30"
            )}
            rows={2}
          />
        </div>

        {/* Back Input */}
        <div className="space-y-2">
          <label htmlFor="back" className="font-mono text-xs tracking-widest uppercase text-paper-muted">
            Définition / Note (Optionnel)
          </label>
          <textarea
            id="back"
            value={back}
            onChange={(e) => setBack(e.target.value)}
            placeholder="Ex: Œdème généralisé sous-cutané..."
            className={cn(
              "w-full rounded-xl p-4 font-sans text-sm resize-none outline-none transition-shadow",
              isDark 
                ? "bg-ink-light text-paper placeholder-paper-muted/30 focus:ring-1 focus:ring-paper/30" 
                : "bg-white text-soot border border-paper-muted/30 placeholder-paper-muted/50 focus:ring-1 focus:ring-soot/30"
            )}
            rows={3}
          />
        </div>

        {/* Tags */}
        <div className="space-y-3">
          <label className="font-mono text-xs tracking-widest uppercase text-paper-muted">
            Catégorie
          </label>
          <div className="flex flex-wrap gap-2">
            {tags.map(tag => (
              <button
                key={tag.id}
                type="button"
                onClick={() => setSelectedTagId(tag.id)}
                className={cn(
                  "px-3 py-1.5 rounded-full font-mono text-xs uppercase tracking-widest font-medium transition-all",
                  selectedTagId === tag.id 
                    ? getTagColorClasses(tag.color, isDark)
                    : isDark ? "bg-ink-light text-paper-muted hover:bg-paper-muted/10" : "bg-white border border-paper-muted/30 text-paper-muted hover:bg-paper-muted/10"
                )}
              >
                {tag.name}
              </button>
            ))}
          </div>
        </div>

        <button
          type="submit"
          disabled={!front.trim() || front.length > 150}
          className={cn(
            "w-full py-4 rounded-xl font-mono text-xs tracking-widest uppercase font-bold transition-all mt-4 disabled:opacity-50 disabled:cursor-not-allowed",
            isDark ? "bg-paper text-ink hover:bg-paper/90" : "bg-soot text-paper hover:bg-soot/90"
          )}
        >
          Créer la carte
        </button>

      </form>

      {/* Preview Section */}
      <div className="pt-8 border-t border-paper-muted/20">
        <h3 className="font-mono text-xs tracking-widest uppercase text-paper-muted mb-4">Aperçu</h3>
        <div className="pointer-events-none">
          <FlashcardItem card={previewCard} isPreview={true} />
        </div>
      </div>

    </div>
  );
}

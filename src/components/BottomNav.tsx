import React from 'react';
import { LayoutDashboard, PlusSquare, Settings2 } from 'lucide-react';
import { useAppContext } from '../context';
import { cn } from '../utils';

export default function BottomNav() {
  const { view, setView, settings } = useAppContext();
  const isDark = settings.theme === 'dark';

  const navItems = [
    { id: 'dashboard', icon: LayoutDashboard, label: 'Accueil' },
    { id: 'add', icon: PlusSquare, label: 'Ajouter' },
    { id: 'settings', icon: Settings2, label: 'Réglages' },
  ] as const;

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-50">
      <div className={cn(
        "max-w-2xl mx-auto border-t flex items-center justify-around pb-safe pt-2 px-2 bg-paper/90 dark:bg-ink/90 backdrop-blur-md transition-colors duration-300",
        isDark ? "border-ink-light" : "border-paper-muted/30"
      )}>
        {navItems.map((item) => {
          const isActive = view === item.id;
          const Icon = item.icon;
          return (
            <button
              key={item.id}
              onClick={() => setView(item.id)}
              className={cn(
                "flex flex-col items-center justify-center w-full py-2 space-y-1 transition-colors duration-200",
                isActive 
                  ? (isDark ? "text-paper" : "text-soot") 
                  : "text-paper-muted dark:text-paper-muted/60"
              )}
            >
              <Icon className="w-5 h-5 stroke-[1.5]" />
              <span className="text-[10px] font-medium tracking-wide uppercase font-sans">
                {item.label}
              </span>
            </button>
          );
        })}
      </div>
    </nav>
  );
}

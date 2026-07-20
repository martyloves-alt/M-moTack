import React, { useMemo } from 'react';
import { Minus, Plus, Moon, Sun } from 'lucide-react';
import { useAppContext } from '../context';
import { cn } from '../utils';

export default function SettingsView() {
  const { settings, updateSettings } = useAppContext();
  const isDark = settings.theme === 'dark';

  const calculateInterval = useMemo(() => {
    try {
      const [startH, startM] = settings.activeHoursStart.split(':').map(Number);
      const [endH, endM] = settings.activeHoursEnd.split(':').map(Number);
      
      let totalMinutes = (endH * 60 + endM) - (startH * 60 + startM);
      if (totalMinutes <= 0) totalMinutes += 24 * 60; // handle crossing midnight if ever allowed

      const intervalHours = totalMinutes / 60 / settings.remindersPerDay;
      return intervalHours.toFixed(1);
    } catch {
      return "0";
    }
  }, [settings.activeHoursStart, settings.activeHoursEnd, settings.remindersPerDay]);

  const handleRemindersChange = (change: number) => {
    const newVal = Math.max(1, Math.min(10, settings.remindersPerDay + change));
    updateSettings({ remindersPerDay: newVal });
  };

  return (
    <div className="space-y-8 pb-10">
      <div>
        <h1 className="font-serif text-3xl font-light tracking-tight mb-2">Réglages</h1>
        <p className="font-sans text-sm text-paper-muted">Ajustez votre rythme d'apprentissage.</p>
      </div>

      <section className="space-y-6">
        <h2 className="font-mono text-xs tracking-widest uppercase text-paper-muted border-b border-paper-muted/20 pb-2">
          Rappels Quotidiens
        </h2>
        
        <div className={cn(
          "rounded-xl p-6 flex flex-col items-center",
          isDark ? "bg-ink-light" : "bg-white border border-paper-muted/30"
        )}>
          <div className="flex items-center space-x-6 mb-6">
            <button 
              onClick={() => handleRemindersChange(-1)}
              disabled={settings.remindersPerDay <= 1}
              className="p-3 rounded-full hover:bg-paper-muted/10 transition-colors disabled:opacity-30"
            >
              <Minus className="w-5 h-5" />
            </button>
            <div className="flex flex-col items-center w-20">
              <span className="font-serif text-5xl font-light">{settings.remindersPerDay}</span>
              <span className="font-mono text-[10px] tracking-widest uppercase text-paper-muted mt-1">
                Fois / Jour
              </span>
            </div>
            <button 
              onClick={() => handleRemindersChange(1)}
              disabled={settings.remindersPerDay >= 10}
              className="p-3 rounded-full hover:bg-paper-muted/10 transition-colors disabled:opacity-30"
            >
              <Plus className="w-5 h-5" />
            </button>
          </div>

          <div className="w-full flex space-x-4">
            <div className="flex-1 flex flex-col space-y-2">
              <label className="font-mono text-[10px] tracking-widest uppercase text-paper-muted">De</label>
              <input 
                type="time" 
                value={settings.activeHoursStart}
                onChange={(e) => updateSettings({ activeHoursStart: e.target.value })}
                className={cn(
                  "px-3 py-2 rounded-lg font-mono text-sm outline-none",
                  isDark ? "bg-ink text-paper" : "bg-paper text-soot border border-paper-muted/30"
                )}
              />
            </div>
            <div className="flex-1 flex flex-col space-y-2">
              <label className="font-mono text-[10px] tracking-widest uppercase text-paper-muted">À</label>
              <input 
                type="time" 
                value={settings.activeHoursEnd}
                onChange={(e) => updateSettings({ activeHoursEnd: e.target.value })}
                className={cn(
                  "px-3 py-2 rounded-lg font-mono text-sm outline-none",
                  isDark ? "bg-ink text-paper" : "bg-paper text-soot border border-paper-muted/30"
                )}
              />
            </div>
          </div>

          <div className="mt-6 pt-4 border-t border-paper-muted/20 w-full text-center">
            <p className="font-sans text-sm text-paper-muted">
              Environ un rappel toutes les <strong className={isDark ? "text-paper font-mono" : "text-soot font-mono"}>{calculateInterval}h</strong>
            </p>
          </div>
        </div>
      </section>

      <section className="space-y-6">
        <h2 className="font-mono text-xs tracking-widest uppercase text-paper-muted border-b border-paper-muted/20 pb-2">
          Apparence
        </h2>
        
        <div className={cn(
          "rounded-xl p-4 flex items-center justify-between",
          isDark ? "bg-ink-light" : "bg-white border border-paper-muted/30"
        )}>
          <div className="flex items-center space-x-3">
            {isDark ? <Moon className="w-5 h-5 text-paper-muted" /> : <Sun className="w-5 h-5 text-paper-muted" />}
            <span className="font-sans text-sm">Mode Sombre</span>
          </div>
          <button
            onClick={() => updateSettings({ theme: isDark ? 'light' : 'dark' })}
            className={cn(
              "w-12 h-6 rounded-full relative transition-colors duration-300",
              isDark ? "bg-coral" : "bg-paper-muted/40"
            )}
          >
            <span className={cn(
              "absolute top-1 left-1 bg-paper w-4 h-4 rounded-full transition-transform duration-300",
              isDark ? "translate-x-6" : "translate-x-0"
            )} />
          </button>
        </div>
      </section>

    </div>
  );
}

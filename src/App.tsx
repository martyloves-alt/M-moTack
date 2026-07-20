import React from 'react';
import { useAppContext } from './context';
import BottomNav from './components/BottomNav';
import DashboardView from './components/DashboardView';
import AddView from './components/AddView';
import SettingsView from './components/SettingsView';

export default function App() {
  const { view } = useAppContext();

  return (
    <div className="flex flex-col h-[100dvh] bg-paper dark:bg-ink text-soot dark:text-paper font-sans transition-colors duration-300">
      <main className="flex-1 overflow-y-auto pb-20 pt-6 px-4 max-w-2xl mx-auto w-full">
        {view === 'dashboard' && <DashboardView />}
        {view === 'add' && <AddView />}
        {view === 'settings' && <SettingsView />}
      </main>
      <BottomNav />
    </div>
  );
}

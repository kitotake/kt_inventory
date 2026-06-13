import React from 'react';
import { createRoot } from 'react-dom/client';
import { Provider } from 'react-redux';
import { DndProvider } from 'react-dnd';
import { TouchBackend } from 'react-dnd-touch-backend';
import { store } from './store';
import App from './App';
import './index.scss';
import { ItemNotificationsProvider } from './components/utils/ItemNotifications';
import { isEnvBrowser } from './utils/misc';

const root = document.getElementById('root');

if (isEnvBrowser()) {
  root!.style.backgroundImage    = 'url("https://i.imgur.com/3pzRj9n.png")';
  root!.style.backgroundSize     = 'cover';
  root!.style.backgroundRepeat   = 'no-repeat';
  root!.style.backgroundPosition = 'center';
}

// Objet stable — défini hors du render pour éviter la réinitialisation du DndProvider
const touchBackendOptions = { enableMouseEvents: true };

createRoot(root!).render(
  <Provider store={store}>
    <DndProvider backend={TouchBackend} options={touchBackendOptions}>
      <ItemNotificationsProvider>
        <App />
      </ItemNotificationsProvider>
    </DndProvider>
  </Provider>
);  
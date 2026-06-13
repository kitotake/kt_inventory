// store/index.ts
import { Action, configureStore, ThunkAction } from '@reduxjs/toolkit';
import { TypedUseSelectorHook, useDispatch, useSelector } from 'react-redux';
import inventoryReducer  from './inventory';
import contextMenuReducer from './contextMenu';
import clothingReducer   from './clothing';
import itemMetaReducer   from './itemMeta';

export const store = configureStore({
  reducer: {
    inventory:   inventoryReducer,
   
    contextMenu: contextMenuReducer,
    clothing:    clothingReducer,
    itemMeta:    itemMetaReducer,
  },
});

export type AppDispatch = typeof store.dispatch;
export type RootState   = ReturnType<typeof store.getState>;
export type AppThunk<ReturnType = void> = ThunkAction<ReturnType, RootState, unknown, Action<string>>;

export const useAppDispatch = () => useDispatch<AppDispatch>();
export const useAppSelector: TypedUseSelectorHook<RootState> = useSelector;
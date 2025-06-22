import React from 'react';
import { Provider } from 'tinybase/ui-react';
import {
  useCreateStore,
  useCreatePersister,
  useCreateIndexes,
} from 'tinybase/ui-react';
import { createStore } from 'tinybase';
import { createIndexedDbPersister } from 'tinybase/persisters/persister-indexed-db';
import { createIndexes } from 'tinybase/indexes';
import { tablesSchema, valuesSchema } from '../services/database';

interface TinyBaseProviderProps {
  children: React.ReactNode;
}

export const TinyBaseProvider: React.FC<TinyBaseProviderProps> = ({
  children,
}) => {
  // Create the store with schema
  const store = useCreateStore(() =>
    createStore().setTablesSchema(tablesSchema).setValuesSchema(valuesSchema),
  );

  // Create indexes for better querying
  const indexes = useCreateIndexes(store, (store) =>
    createIndexes(store)
      .setIndexDefinition('nodesByType', 'nodes', 'type')
      .setIndexDefinition('imagesBySource', 'images', 'source')
      .setIndexDefinition('apiKeysByProvider', 'apiKeys', 'provider'),
  );

  // Create and configure IndexedDB persister
  const persister = useCreatePersister(
    store,
    async (store) => {
      console.log('Creating TinyBase IndexedDB persister...');
      return createIndexedDbPersister(store, 'hitSlopFlowDatabase');
    },
    [],
    async (persister) => {
      console.log('Starting TinyBase auto-persistence...');
      await persister.startAutoPersisting();
      console.log('TinyBase auto-persistence started successfully');
    },
  );

  return (
    <Provider
      store={store}
      storesById={{ main: store }}
      {...(indexes && { indexes, indexesById: { main: indexes } })}
      persister={persister}
    >
      {children}
    </Provider>
  );
};

export default TinyBaseProvider;

// Monorepo shim — required because npm workspaces hoists `expo` to the root node_modules.
// expo/AppEntry.js (at da/node_modules/expo/AppEntry.js) resolves '../../App' to this file.
// This file simply re-exports the mobile app component so Expo Go can find it.
export { default } from './apps/mobile/App';

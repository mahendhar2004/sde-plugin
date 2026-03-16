# React Native + Expo Patterns Reference

Quick reference for React Native + Expo + TypeScript patterns. Agents read this before generating mobile code.

---

## Expo Router File Conventions
```
app/
├── _layout.tsx              # Root: QueryClient, AuthCheck, Fonts
├── (auth)/
│   ├── _layout.tsx          # Auth stack (no tab bar)
│   ├── login.tsx
│   └── register.tsx
├── (tabs)/
│   ├── _layout.tsx          # Tab bar config
│   ├── index.tsx            # Home tab (/)
│   ├── explore.tsx
│   └── profile.tsx
├── [feature]/
│   ├── index.tsx            # /feature (list)
│   └── [id].tsx             # /feature/123 (detail)
└── modal.tsx                # Presented as modal
```

---

## Root Layout — Required Setup
```typescript
// app/_layout.tsx
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { Stack } from 'expo-router';
import { useFonts, Inter_400Regular, Inter_600SemiBold } from '@expo-google-fonts/inter';
import * as SplashScreen from 'expo-splash-screen';
import { useEffect } from 'react';

SplashScreen.preventAutoHideAsync();
const queryClient = new QueryClient({ defaultOptions: { queries: { retry: 2 } } });

export default function RootLayout() {
  const [fontsLoaded] = useFonts({ Inter_400Regular, Inter_600SemiBold });

  useEffect(() => {
    if (fontsLoaded) SplashScreen.hideAsync();
  }, [fontsLoaded]);

  if (!fontsLoaded) return null;

  return (
    <QueryClientProvider client={queryClient}>
      <Stack>
        <Stack.Screen name="(auth)" options={{ headerShown: false }} />
        <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
      </Stack>
    </QueryClientProvider>
  );
}
```

---

## Auth Check Pattern (auto-redirect)
```typescript
// hooks/useAuthRedirect.ts
import { useRouter, useSegments } from 'expo-router';
import { useEffect } from 'react';
import { useAuthStore } from '../store/auth.store';

export function useAuthRedirect() {
  const isAuthenticated = useAuthStore(s => s.isAuthenticated);
  const segments = useSegments();
  const router = useRouter();

  useEffect(() => {
    const inAuthGroup = segments[0] === '(auth)';
    if (!isAuthenticated && !inAuthGroup) {
      router.replace('/(auth)/login');
    } else if (isAuthenticated && inAuthGroup) {
      router.replace('/(tabs)');
    }
  }, [isAuthenticated, segments]);
}
```

---

## Screen Pattern (all states)
```typescript
import { View, FlatList, RefreshControl, StyleSheet } from 'react-native';

export default function ItemsScreen() {
  const { data, isLoading, error, refetch, isFetching } = useItems();

  if (isLoading) return <LoadingSkeleton count={5} />;
  if (error) return <ErrorState onRetry={refetch} />;

  return (
    <View style={styles.container}>
      <FlatList
        data={data?.items ?? []}
        keyExtractor={item => item.id}
        renderItem={({ item }) => <ItemCard item={item} />}
        ListEmptyComponent={<EmptyState message="No items found" />}
        refreshControl={
          <RefreshControl refreshing={isFetching && !isLoading} onRefresh={refetch} />
        }
        contentContainerStyle={styles.list}
        showsVerticalScrollIndicator={false}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#F9FAFB' },
  list: { padding: 16, gap: 12 },
});
```

---

## Secure Token Storage
```typescript
// utils/tokenStorage.ts
import * as SecureStore from 'expo-secure-store';

export const tokenStorage = {
  getAccessToken: () => SecureStore.getItemAsync('access_token'),
  getRefreshToken: () => SecureStore.getItemAsync('refresh_token'),
  setTokens: (access: string, refresh: string) =>
    Promise.all([
      SecureStore.setItemAsync('access_token', access),
      SecureStore.setItemAsync('refresh_token', refresh),
    ]),
  clearTokens: () =>
    Promise.all([
      SecureStore.deleteItemAsync('access_token'),
      SecureStore.deleteItemAsync('refresh_token'),
    ]),
};
```

---

## API Service (same Axios pattern as web)
```typescript
// services/api.ts
import axios from 'axios';
import { tokenStorage } from '../utils/tokenStorage';

const api = axios.create({
  baseURL: process.env.EXPO_PUBLIC_API_URL,
  timeout: 10_000,
});

api.interceptors.request.use(async (config) => {
  const token = await tokenStorage.getAccessToken();
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

// Refresh token interceptor (same logic as web, uses SecureStore)
```

---

## Form with Keyboard Handling
```typescript
import { KeyboardAvoidingView, Platform, ScrollView } from 'react-native';

export function LoginForm() {
  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      style={{ flex: 1 }}
    >
      <ScrollView keyboardShouldPersistTaps="handled" contentContainerStyle={{ flexGrow: 1 }}>
        {/* form fields */}
      </ScrollView>
    </KeyboardAvoidingView>
  );
}
```

---

## NativeWind (Tailwind for RN)
```typescript
// Use className prop (NativeWind v4 with Expo)
<View className="flex-1 bg-gray-50 px-4 py-6">
  <Text className="text-2xl font-semibold text-gray-900">Hello</Text>
  <Pressable className="mt-4 rounded-xl bg-indigo-600 py-3 active:opacity-80">
    <Text className="text-center font-medium text-white">Submit</Text>
  </Pressable>
</View>
```

---

## Offline Detection
```typescript
// hooks/useNetworkStatus.ts
import NetInfo from '@react-native-community/netinfo';

export function useNetworkStatus() {
  const [isConnected, setIsConnected] = useState(true);
  useEffect(() => {
    return NetInfo.addEventListener(state => {
      setIsConnected(state.isConnected ?? true);
    });
  }, []);
  return { isConnected };
}

// Offline Banner component
export function OfflineBanner() {
  const { isConnected } = useNetworkStatus();
  if (isConnected) return null;
  return (
    <View className="bg-red-500 px-4 py-2">
      <Text className="text-center text-sm font-medium text-white">
        No internet connection
      </Text>
    </View>
  );
}
```

---

## Push Notification Setup
```typescript
// utils/notifications.ts
import * as Notifications from 'expo-notifications';
import * as Device from 'expo-device';

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: true,
    shouldSetBadge: true,
  }),
});

export async function registerForPushNotifications(): Promise<string | null> {
  if (!Device.isDevice) return null; // simulator doesn't support push

  const { status: existing } = await Notifications.getPermissionsAsync();
  let finalStatus = existing;
  if (existing !== 'granted') {
    const { status } = await Notifications.requestPermissionsAsync();
    finalStatus = status;
  }
  if (finalStatus !== 'granted') return null;

  const token = (await Notifications.getExpoPushTokenAsync()).data;
  return token;
}
```

---

## Touch Target Size Rule
All touchable elements must be at least 44x44 points (Apple HIG + Android guidelines):
```typescript
<Pressable
  style={{ minWidth: 44, minHeight: 44, justifyContent: 'center', alignItems: 'center' }}
  hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
>
```

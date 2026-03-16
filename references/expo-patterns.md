# Expo Patterns Reference

Complete, production-ready React Native / Expo patterns. Agents read this before generating mobile code.
Target: Expo SDK 51+, Expo Router v3 (file-based routing), TypeScript.

---

## 1. Project Structure

```
app/
  _layout.tsx                  ← root layout: QueryClient, auth listener, fonts, splash
  (auth)/
    _layout.tsx                ← auth stack layout (no tab bar, no back button)
    login.tsx
    register.tsx
  (app)/
    _layout.tsx                ← authenticated layout with bottom tab bar
    index.tsx                  ← home screen  (tab: Home)
    profile.tsx                ← profile screen (tab: Profile)
    (modal)/
      settings.tsx             ← presented as a modal over the tab layout
  +not-found.tsx               ← 404 screen

components/
  ui/
    Button.tsx
    Input.tsx
    Badge.tsx
  layout/
    OfflineBanner.tsx
    SafeAreaWrapper.tsx

hooks/
  useAuth.ts
  useProfile.ts
  useAppState.ts
  useNetworkStatus.ts

lib/
  supabase.ts                  ← singleton Supabase client (SecureStore adapter)
  api.ts                       ← typed query functions

stores/
  auth.store.ts                ← Zustand auth state

types/
  supabase.ts                  ← generated via: npx supabase gen types typescript
  index.ts                     ← app-specific types
```

---

## 2. Root Layout with Auth Redirect

```typescript
// app/_layout.tsx
import 'react-native-url-polyfill/auto';
import { useEffect, useCallback } from 'react';
import { AppState } from 'react-native';
import { Stack, useRouter, useSegments } from 'expo-router';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import * as SplashScreen from 'expo-splash-screen';
import * as Linking from 'expo-linking';
import { useFonts, Inter_400Regular, Inter_600SemiBold } from '@expo-google-fonts/inter';
import { supabase } from '@/lib/supabase';
import { useAuthStore } from '@/stores/auth.store';

SplashScreen.preventAutoHideAsync();

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 2,
      staleTime: 1000 * 60 * 5, // 5 minutes
    },
  },
});

function AuthGate({ children }: { children: React.ReactNode }) {
  const { session, setSession } = useAuthStore();
  const segments = useSegments();
  const router = useRouter();

  // Handle auth redirects whenever session or current segment changes
  useEffect(() => {
    const inAuthGroup = segments[0] === '(auth)';

    if (!session && !inAuthGroup) {
      // No session — send to login
      router.replace('/(auth)/login');
    } else if (session && inAuthGroup) {
      // Has session — send to app
      router.replace('/(app)');
    }
  }, [session, segments]);

  // Subscribe to auth state changes (handles OAuth callback, magic link, token refresh)
  useEffect(() => {
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      (_event, newSession) => {
        setSession(newSession);
      },
    );
    return () => subscription.unsubscribe();
  }, []);

  // Handle incoming deep links (OAuth callback, magic link)
  useEffect(() => {
    const handleDeepLink = async (url: string) => {
      // Supabase exchangeCodeForSession handles the PKCE code in the URL
      if (url.includes('code=')) {
        await supabase.auth.exchangeCodeForSession(url);
      }
    };

    // Handle link that opened the app
    Linking.getInitialURL().then((url) => {
      if (url) handleDeepLink(url);
    });

    // Handle links when app is already open
    const subscription = Linking.addEventListener('url', ({ url }) => {
      handleDeepLink(url);
    });

    return () => subscription.remove();
  }, []);

  return <>{children}</>;
}

export default function RootLayout() {
  const [fontsLoaded] = useFonts({ Inter_400Regular, Inter_600SemiBold });

  const onLayoutRootView = useCallback(async () => {
    if (fontsLoaded) {
      await SplashScreen.hideAsync();
    }
  }, [fontsLoaded]);

  if (!fontsLoaded) return null;

  return (
    <QueryClientProvider client={queryClient}>
      <AuthGate>
        <Stack onLayout={onLayoutRootView}>
          <Stack.Screen name="(auth)" options={{ headerShown: false }} />
          <Stack.Screen name="(app)" options={{ headerShown: false }} />
          <Stack.Screen name="+not-found" />
        </Stack>
      </AuthGate>
    </QueryClientProvider>
  );
}
```

---

## 3. Authenticated Layout

```typescript
// app/(app)/_layout.tsx
import { Tabs } from 'expo-router';
import { Platform } from 'react-native';
import { Home, User, Bell } from 'lucide-react-native';
import { OfflineBanner } from '@/components/layout/OfflineBanner';

export default function AppLayout() {
  return (
    <>
      <OfflineBanner />
      <Tabs
        screenOptions={{
          headerShown: false,
          tabBarActiveTintColor: '#4F46E5',
          tabBarInactiveTintColor: '#9CA3AF',
          tabBarStyle: {
            backgroundColor: '#FFFFFF',
            borderTopColor: '#E5E7EB',
            paddingBottom: Platform.OS === 'ios' ? 20 : 8,
            height: Platform.OS === 'ios' ? 84 : 60,
          },
          tabBarLabelStyle: {
            fontSize: 12,
            fontFamily: 'Inter_600SemiBold',
          },
        }}
      >
        <Tabs.Screen
          name="index"
          options={{
            title: 'Home',
            tabBarIcon: ({ color, size }) => <Home color={color} size={size} />,
          }}
        />
        <Tabs.Screen
          name="notifications"
          options={{
            title: 'Alerts',
            tabBarIcon: ({ color, size }) => <Bell color={color} size={size} />,
          }}
        />
        <Tabs.Screen
          name="profile"
          options={{
            title: 'Profile',
            tabBarIcon: ({ color, size }) => <User color={color} size={size} />,
          }}
        />
        {/* Hide modal screens from tab bar */}
        <Tabs.Screen name="(modal)" options={{ href: null }} />
      </Tabs>
    </>
  );
}
```

---

## 4. Supabase Client for React Native

```typescript
// lib/supabase.ts
import 'react-native-url-polyfill/auto';
import { createClient } from '@supabase/supabase-js';
import * as SecureStore from 'expo-secure-store';
import { AppState } from 'react-native';
import { Database } from '@/types/supabase';

// SecureStore has a 2048-byte limit per key, so we chunk large values.
// Supabase session tokens frequently exceed this limit.
const ExpoSecureStoreAdapter = {
  getItem: async (key: string): Promise<string | null> => {
    const chunksCountStr = await SecureStore.getItemAsync(`${key}_chunks`);
    if (chunksCountStr !== null) {
      const chunksCount = parseInt(chunksCountStr, 10);
      const parts: string[] = [];
      for (let i = 0; i < chunksCount; i++) {
        const chunk = await SecureStore.getItemAsync(`${key}_chunk_${i}`);
        if (chunk === null) return null;
        parts.push(chunk);
      }
      return parts.join('');
    }
    return SecureStore.getItemAsync(key);
  },

  setItem: async (key: string, value: string): Promise<void> => {
    const CHUNK_SIZE = 1800;
    if (value.length <= CHUNK_SIZE) {
      await SecureStore.setItemAsync(key, value);
      return;
    }
    const chunks = Math.ceil(value.length / CHUNK_SIZE);
    await SecureStore.setItemAsync(`${key}_chunks`, String(chunks));
    for (let i = 0; i < chunks; i++) {
      await SecureStore.setItemAsync(
        `${key}_chunk_${i}`,
        value.slice(i * CHUNK_SIZE, (i + 1) * CHUNK_SIZE),
      );
    }
  },

  removeItem: async (key: string): Promise<void> => {
    const chunksCountStr = await SecureStore.getItemAsync(`${key}_chunks`);
    if (chunksCountStr !== null) {
      const chunksCount = parseInt(chunksCountStr, 10);
      for (let i = 0; i < chunksCount; i++) {
        await SecureStore.deleteItemAsync(`${key}_chunk_${i}`);
      }
      await SecureStore.deleteItemAsync(`${key}_chunks`);
    }
    await SecureStore.deleteItemAsync(key);
  },
};

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY!;

export const supabase = createClient<Database>(supabaseUrl, supabaseAnonKey, {
  auth: {
    storage: ExpoSecureStoreAdapter,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false, // Not applicable for native apps
  },
});

// Pause token refresh when app is in background; resume on foreground
AppState.addEventListener('change', (state) => {
  if (state === 'active') {
    supabase.auth.startAutoRefresh();
  } else {
    supabase.auth.stopAutoRefresh();
  }
});
```

---

## 5. Custom Hooks

### useAuth()
```typescript
// hooks/useAuth.ts
import { useState, useEffect } from 'react';
import { Session, User } from '@supabase/supabase-js';
import { supabase } from '@/lib/supabase';

interface AuthState {
  user: User | null;
  session: Session | null;
  loading: boolean;
}

interface AuthActions {
  signIn: (email: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
}

export function useAuth(): AuthState & AuthActions {
  const [user, setUser] = useState<User | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Restore session from SecureStore on mount
    supabase.auth.getSession().then(({ data: { session: existing } }) => {
      setSession(existing);
      setUser(existing?.user ?? null);
      setLoading(false);
    });

    // Listen for subsequent auth state changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      (_event, newSession) => {
        setSession(newSession);
        setUser(newSession?.user ?? null);
      },
    );

    return () => subscription.unsubscribe();
  }, []);

  const signIn = async (email: string, password: string): Promise<void> => {
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) throw error;
  };

  const signOut = async (): Promise<void> => {
    const { error } = await supabase.auth.signOut();
    if (error) throw error;
  };

  return { user, session, loading, signIn, signOut };
}
```

### useProfile()
```typescript
// hooks/useProfile.ts
import { useQuery } from '@tanstack/react-query';
import { supabase } from '@/lib/supabase';
import { Database } from '@/types/supabase';

type Profile = Database['public']['Tables']['profiles']['Row'];

async function fetchProfile(userId: string): Promise<Profile> {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', userId)
    .single();

  if (error) throw error;
  return data;
}

export function useProfile(userId: string | undefined) {
  return useQuery({
    queryKey: ['profiles', 'detail', userId],
    queryFn: () => fetchProfile(userId!),
    staleTime: 1000 * 60 * 5,
    enabled: Boolean(userId),
  });
}
```

### useAppState()
```typescript
// hooks/useAppState.ts
import { useEffect, useRef } from 'react';
import { AppState, AppStateStatus } from 'react-native';

type AppStateChangeCallback = (nextState: AppStateStatus) => void;

export function useAppState(onChange: AppStateChangeCallback): void {
  const appState = useRef<AppStateStatus>(AppState.currentState);

  useEffect(() => {
    const subscription = AppState.addEventListener('change', (nextState) => {
      if (appState.current !== nextState) {
        onChange(nextState);
        appState.current = nextState;
      }
    });

    return () => subscription.remove();
  }, [onChange]);
}

// Usage: pause/resume Supabase token refresh
import { useCallback } from 'react';
import { supabase } from '@/lib/supabase';

export function useSupabaseAppState(): void {
  const handleAppStateChange = useCallback((nextState: AppStateStatus) => {
    if (nextState === 'active') {
      supabase.auth.startAutoRefresh();
    } else {
      supabase.auth.stopAutoRefresh();
    }
  }, []);

  useAppState(handleAppStateChange);
}
```

---

## 6. Screen Pattern

```typescript
// app/(app)/index.tsx
import {
  View,
  Text,
  FlatList,
  RefreshControl,
  ActivityIndicator,
  Pressable,
} from 'react-native';
import { useQuery } from '@tanstack/react-query';
import { supabase } from '@/lib/supabase';
import { Database } from '@/types/supabase';

type Post = Database['public']['Tables']['posts']['Row'];

async function fetchPosts(): Promise<Post[]> {
  const { data, error } = await supabase
    .from('posts')
    .select('*')
    .is('deleted_at', null)
    .order('created_at', { ascending: false });

  if (error) throw error;
  return data;
}

export default function HomeScreen() {
  const {
    data,
    isLoading,
    isError,
    error,
    refetch,
    isFetching,
  } = useQuery({
    queryKey: ['posts', 'list'],
    queryFn: fetchPosts,
  });

  // Loading state
  if (isLoading) {
    return (
      <View className="flex-1 items-center justify-center bg-gray-50">
        <ActivityIndicator size="large" color="#4F46E5" />
      </View>
    );
  }

  // Error state
  if (isError) {
    return (
      <View className="flex-1 items-center justify-center bg-gray-50 px-6">
        <Text className="text-lg font-semibold text-gray-900 text-center">
          Failed to load posts
        </Text>
        <Text className="mt-2 text-sm text-gray-500 text-center">
          {error instanceof Error ? error.message : 'An unexpected error occurred.'}
        </Text>
        <Pressable
          className="mt-6 rounded-xl bg-indigo-600 px-6 py-3 active:opacity-75"
          onPress={() => refetch()}
        >
          <Text className="text-base font-semibold text-white">Try again</Text>
        </Pressable>
      </View>
    );
  }

  // Empty state
  if (!data || data.length === 0) {
    return (
      <View className="flex-1 items-center justify-center bg-gray-50 px-6">
        <Text className="text-lg font-semibold text-gray-900">No posts yet</Text>
        <Text className="mt-2 text-sm text-gray-500 text-center">
          Be the first to create a post.
        </Text>
      </View>
    );
  }

  // Data state
  return (
    <View className="flex-1 bg-gray-50">
      <FlatList<Post>
        data={data}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => (
          <View className="mx-4 my-2 rounded-2xl bg-white p-4 shadow-sm">
            <Text className="text-base font-semibold text-gray-900">{item.title}</Text>
            <Text className="mt-1 text-sm text-gray-500" numberOfLines={2}>
              {item.body}
            </Text>
          </View>
        )}
        ListHeaderComponent={
          <Text className="px-4 pt-6 pb-2 text-2xl font-semibold text-gray-900">
            Posts
          </Text>
        }
        contentContainerStyle={{ paddingBottom: 32 }}
        showsVerticalScrollIndicator={false}
        // Pull-to-refresh
        refreshControl={
          <RefreshControl
            refreshing={isFetching && !isLoading}
            onRefresh={refetch}
            tintColor="#4F46E5"
          />
        }
      />
    </View>
  );
}
```

---

## 7. Form Pattern

```typescript
// app/(auth)/login.tsx
import {
  View,
  Text,
  TextInput,
  Pressable,
  KeyboardAvoidingView,
  ScrollView,
  Platform,
  ActivityIndicator,
} from 'react-native';
import { useForm, Controller } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useState } from 'react';
import { router } from 'expo-router';
import { supabase } from '@/lib/supabase';

const loginSchema = z.object({
  email: z.string().email('Enter a valid email address'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
});

type LoginFormValues = z.infer<typeof loginSchema>;

export default function LoginScreen() {
  const [submitError, setSubmitError] = useState<string | null>(null);

  const {
    control,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<LoginFormValues>({
    resolver: zodResolver(loginSchema),
    defaultValues: { email: '', password: '' },
  });

  const onSubmit = async (values: LoginFormValues) => {
    setSubmitError(null);
    const { error } = await supabase.auth.signInWithPassword({
      email: values.email,
      password: values.password,
    });

    if (error) {
      setSubmitError(
        error.message.includes('Invalid login credentials')
          ? 'Invalid email or password.'
          : error.message,
      );
      return;
    }

    // Auth listener in root layout will redirect to (app)
  };

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      className="flex-1 bg-white"
    >
      <ScrollView
        contentContainerStyle={{ flexGrow: 1 }}
        keyboardShouldPersistTaps="handled"
        showsVerticalScrollIndicator={false}
      >
        <View className="flex-1 justify-center px-6 py-12">
          <Text className="text-3xl font-semibold text-gray-900">Welcome back</Text>
          <Text className="mt-2 text-base text-gray-500">Sign in to continue</Text>

          <View className="mt-8 gap-5">
            {/* Email field */}
            <View>
              <Text className="mb-1.5 text-sm font-medium text-gray-700">Email</Text>
              <Controller
                control={control}
                name="email"
                render={({ field: { onChange, onBlur, value } }) => (
                  <TextInput
                    className={`rounded-xl border px-4 py-3 text-base text-gray-900 ${
                      errors.email ? 'border-red-500 bg-red-50' : 'border-gray-300 bg-white'
                    }`}
                    placeholder="you@example.com"
                    autoCapitalize="none"
                    autoCorrect={false}
                    keyboardType="email-address"
                    returnKeyType="next"
                    onBlur={onBlur}
                    onChangeText={onChange}
                    value={value}
                  />
                )}
              />
              {errors.email && (
                <Text className="mt-1 text-sm text-red-600">{errors.email.message}</Text>
              )}
            </View>

            {/* Password field */}
            <View>
              <Text className="mb-1.5 text-sm font-medium text-gray-700">Password</Text>
              <Controller
                control={control}
                name="password"
                render={({ field: { onChange, onBlur, value } }) => (
                  <TextInput
                    className={`rounded-xl border px-4 py-3 text-base text-gray-900 ${
                      errors.password ? 'border-red-500 bg-red-50' : 'border-gray-300 bg-white'
                    }`}
                    placeholder="••••••••"
                    secureTextEntry
                    returnKeyType="done"
                    onBlur={onBlur}
                    onChangeText={onChange}
                    value={value}
                    onSubmitEditing={handleSubmit(onSubmit)}
                  />
                )}
              />
              {errors.password && (
                <Text className="mt-1 text-sm text-red-600">{errors.password.message}</Text>
              )}
            </View>
          </View>

          {/* Submit error */}
          {submitError && (
            <View className="mt-4 rounded-xl bg-red-50 px-4 py-3">
              <Text className="text-sm text-red-700">{submitError}</Text>
            </View>
          )}

          {/* Submit button */}
          <Pressable
            className={`mt-8 rounded-xl py-4 active:opacity-80 ${
              isSubmitting ? 'bg-indigo-400' : 'bg-indigo-600'
            }`}
            onPress={handleSubmit(onSubmit)}
            disabled={isSubmitting}
          >
            {isSubmitting ? (
              <ActivityIndicator color="white" />
            ) : (
              <Text className="text-center text-base font-semibold text-white">
                Sign in
              </Text>
            )}
          </Pressable>

          {/* Navigation link */}
          <Pressable
            className="mt-4 py-2"
            onPress={() => router.push('/(auth)/register')}
          >
            <Text className="text-center text-sm text-gray-500">
              Don't have an account?{' '}
              <Text className="font-semibold text-indigo-600">Sign up</Text>
            </Text>
          </Pressable>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}
```

---

## 8. API Service Layer

```typescript
// lib/api.ts
import { supabase } from '@/lib/supabase';
import { Database } from '@/types/supabase';

type Profile = Database['public']['Tables']['profiles']['Row'];
type ProfileInsert = Database['public']['Tables']['profiles']['Insert'];
type ProfileUpdate = Database['public']['Tables']['profiles']['Update'];
type Post = Database['public']['Tables']['posts']['Row'];
type PostInsert = Database['public']['Tables']['posts']['Insert'];

// Typed result wrapper — mirrors Supabase's own { data, error } shape
export type ApiResult<T> =
  | { data: T; error: null }
  | { data: null; error: Error };

function ok<T>(data: T): ApiResult<T> {
  return { data, error: null };
}

function err(error: unknown): ApiResult<never> {
  return {
    data: null,
    error: error instanceof Error ? error : new Error(String(error)),
  };
}

// ─── Profiles ────────────────────────────────────────────────────────────────

export const profilesApi = {
  getById: async (id: string): Promise<ApiResult<Profile>> => {
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', id)
        .single();
      if (error) return err(error);
      return ok(data);
    } catch (e) {
      return err(e);
    }
  },

  update: async (id: string, updates: ProfileUpdate): Promise<ApiResult<Profile>> => {
    try {
      const { data, error } = await supabase
        .from('profiles')
        .update(updates)
        .eq('id', id)
        .select()
        .single();
      if (error) return err(error);
      return ok(data);
    } catch (e) {
      return err(e);
    }
  },
};

// ─── Posts ────────────────────────────────────────────────────────────────────

export const postsApi = {
  list: async (userId: string): Promise<ApiResult<Post[]>> => {
    try {
      const { data, error } = await supabase
        .from('posts')
        .select('*')
        .eq('user_id', userId)
        .is('deleted_at', null)
        .order('created_at', { ascending: false });
      if (error) return err(error);
      return ok(data);
    } catch (e) {
      return err(e);
    }
  },

  create: async (input: PostInsert): Promise<ApiResult<Post>> => {
    try {
      const { data, error } = await supabase
        .from('posts')
        .insert(input)
        .select()
        .single();
      if (error) return err(error);
      return ok(data);
    } catch (e) {
      return err(e);
    }
  },

  softDelete: async (id: string): Promise<ApiResult<void>> => {
    try {
      const { error } = await supabase
        .from('posts')
        .update({ deleted_at: new Date().toISOString() })
        .eq('id', id);
      if (error) return err(error);
      return ok(undefined);
    } catch (e) {
      return err(e);
    }
  },
};
```

---

## 9. Secure Token Storage

**Why NOT AsyncStorage for tokens:**
- AsyncStorage is unencrypted on disk — any app or process with file system access can read it
- On jailbroken/rooted devices, AsyncStorage data is trivially extracted
- expo-secure-store uses iOS Keychain (hardware-backed on modern iPhones) and Android Keystore
- Supabase's own documentation recommends SecureStore for React Native

```typescript
// lib/supabase.ts — custom storage adapter
import * as SecureStore from 'expo-secure-store';

// SecureStore limit: 2048 bytes per key.
// A Supabase session JSON is typically 1500–3000 bytes, so chunking is necessary.
const CHUNK_SIZE = 1800;

export const ExpoSecureStoreAdapter = {
  getItem: async (key: string): Promise<string | null> => {
    const chunksCountStr = await SecureStore.getItemAsync(`${key}_chunks`);
    if (chunksCountStr !== null) {
      const count = parseInt(chunksCountStr, 10);
      const parts: string[] = [];
      for (let i = 0; i < count; i++) {
        const chunk = await SecureStore.getItemAsync(`${key}_chunk_${i}`);
        if (chunk === null) return null;
        parts.push(chunk);
      }
      return parts.join('');
    }
    return SecureStore.getItemAsync(key);
  },

  setItem: async (key: string, value: string): Promise<void> => {
    if (value.length <= CHUNK_SIZE) {
      await SecureStore.setItemAsync(key, value);
      return;
    }
    const count = Math.ceil(value.length / CHUNK_SIZE);
    await SecureStore.setItemAsync(`${key}_chunks`, String(count));
    for (let i = 0; i < count; i++) {
      await SecureStore.setItemAsync(
        `${key}_chunk_${i}`,
        value.slice(i * CHUNK_SIZE, (i + 1) * CHUNK_SIZE),
      );
    }
  },

  removeItem: async (key: string): Promise<void> => {
    const chunksCountStr = await SecureStore.getItemAsync(`${key}_chunks`);
    if (chunksCountStr !== null) {
      const count = parseInt(chunksCountStr, 10);
      for (let i = 0; i < count; i++) {
        await SecureStore.deleteItemAsync(`${key}_chunk_${i}`);
      }
      await SecureStore.deleteItemAsync(`${key}_chunks`);
    }
    await SecureStore.deleteItemAsync(key);
  },
};

// Pass adapter to createClient:
// createClient(url, key, { auth: { storage: ExpoSecureStoreAdapter } })
```

---

## 10. Offline Detection + Handling

```typescript
// hooks/useNetworkStatus.ts
import { useState, useEffect } from 'react';
import NetInfo, { NetInfoState } from '@react-native-community/netinfo';

interface NetworkStatus {
  isConnected: boolean;
  isInternetReachable: boolean | null;
}

export function useNetworkStatus(): NetworkStatus {
  const [status, setStatus] = useState<NetworkStatus>({
    isConnected: true,
    isInternetReachable: true,
  });

  useEffect(() => {
    const unsubscribe = NetInfo.addEventListener((state: NetInfoState) => {
      setStatus({
        isConnected: state.isConnected ?? true,
        isInternetReachable: state.isInternetReachable,
      });
    });

    return unsubscribe;
  }, []);

  return status;
}
```

```typescript
// components/layout/OfflineBanner.tsx
import { View, Text, Animated, useEffect, useRef } from 'react-native';
import { useNetworkStatus } from '@/hooks/useNetworkStatus';

export function OfflineBanner() {
  const { isConnected } = useNetworkStatus();
  const translateY = useRef(new Animated.Value(-50)).current;

  useEffect(() => {
    Animated.timing(translateY, {
      toValue: isConnected ? -50 : 0,
      duration: 300,
      useNativeDriver: true,
    }).start();
  }, [isConnected]);

  return (
    <Animated.View
      style={{ transform: [{ translateY }] }}
      className="absolute top-0 left-0 right-0 z-50 bg-red-500 px-4 py-2"
    >
      <Text className="text-center text-sm font-medium text-white">
        No internet connection
      </Text>
    </Animated.View>
  );
}
```

```typescript
// Mutation queue: retry failed mutations when connectivity is restored
// hooks/useMutationQueue.ts
import { useRef, useCallback, useEffect } from 'react';
import { useNetworkStatus } from '@/hooks/useNetworkStatus';

type QueuedMutation = () => Promise<void>;

export function useMutationQueue() {
  const { isConnected } = useNetworkStatus();
  const queue = useRef<QueuedMutation[]>([]);

  // Drain queue when connection is restored
  useEffect(() => {
    if (!isConnected) return;

    const drain = async () => {
      while (queue.current.length > 0) {
        const mutation = queue.current.shift()!;
        try {
          await mutation();
        } catch (err) {
          console.error('Queued mutation failed:', err);
        }
      }
    };

    drain();
  }, [isConnected]);

  const enqueue = useCallback((mutation: QueuedMutation) => {
    if (isConnected) {
      mutation().catch((err) => console.error('Mutation failed:', err));
    } else {
      queue.current.push(mutation);
    }
  }, [isConnected]);

  return { enqueue };
}
```

---

## 11. Push Notifications (Expo)

```typescript
// lib/notifications.ts
import * as Notifications from 'expo-notifications';
import * as Device from 'expo-device';
import { Platform } from 'react-native';
import { supabase } from '@/lib/supabase';

// Configure how notifications are displayed when the app is in the foreground
Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: true,
    shouldSetBadge: true,
  }),
});

export async function registerForPushNotificationsAsync(): Promise<string | null> {
  if (!Device.isDevice) {
    console.warn('Push notifications require a physical device.');
    return null;
  }

  // Android: create a notification channel
  if (Platform.OS === 'android') {
    await Notifications.setNotificationChannelAsync('default', {
      name: 'default',
      importance: Notifications.AndroidImportance.MAX,
      vibrationPattern: [0, 250, 250, 250],
      lightColor: '#4F46E5',
    });
  }

  const { status: existingStatus } = await Notifications.getPermissionsAsync();
  let finalStatus = existingStatus;

  if (existingStatus !== 'granted') {
    const { status } = await Notifications.requestPermissionsAsync();
    finalStatus = status;
  }

  if (finalStatus !== 'granted') {
    console.warn('Push notification permission not granted.');
    return null;
  }

  const tokenData = await Notifications.getExpoPushTokenAsync({
    projectId: process.env.EXPO_PUBLIC_PROJECT_ID!, // EAS project ID
  });

  return tokenData.data;
}

// Save the device push token to Supabase so the server can send notifications
export async function savePushTokenToSupabase(token: string): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return;

  const { error } = await supabase
    .from('device_tokens')
    .upsert(
      {
        user_id: user.id,
        token,
        platform: Platform.OS,
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'user_id,token' },
    );

  if (error) console.error('Failed to save push token:', error);
}
```

```typescript
// hooks/usePushNotifications.ts
import { useEffect, useRef } from 'react';
import * as Notifications from 'expo-notifications';
import { router } from 'expo-router';
import { registerForPushNotificationsAsync, savePushTokenToSupabase } from '@/lib/notifications';

export function usePushNotifications(): void {
  const notificationListener = useRef<Notifications.EventSubscription>();
  const responseListener = useRef<Notifications.EventSubscription>();

  useEffect(() => {
    // Register and save token
    registerForPushNotificationsAsync()
      .then((token) => {
        if (token) savePushTokenToSupabase(token);
      })
      .catch(console.error);

    // Handle notification received while app is in the foreground
    notificationListener.current = Notifications.addNotificationReceivedListener(
      (notification) => {
        console.log('Notification received in foreground:', notification);
        // You can update UI state here (e.g., increment badge count)
      },
    );

    // Handle notification tap (app was in background or closed)
    responseListener.current = Notifications.addNotificationResponseReceivedListener(
      (response) => {
        const data = response.notification.request.content.data;

        // Navigate to the relevant screen based on notification payload
        if (data.screen === 'post' && data.postId) {
          router.push(`/(app)/posts/${data.postId}`);
        } else if (data.screen === 'profile' && data.userId) {
          router.push(`/(app)/profile`);
        }
      },
    );

    return () => {
      notificationListener.current?.remove();
      responseListener.current?.remove();
    };
  }, []);
}
```

---

## 12. Deep Linking for OAuth / Magic Link

### app.json scheme config
```json
{
  "expo": {
    "scheme": "myapp",
    "ios": {
      "bundleIdentifier": "com.yourcompany.myapp"
    },
    "android": {
      "package": "com.yourcompany.myapp",
      "intentFilters": [
        {
          "action": "VIEW",
          "autoVerify": true,
          "data": [
            {
              "scheme": "myapp",
              "host": "auth",
              "pathPrefix": "/callback"
            }
          ],
          "category": ["BROWSABLE", "DEFAULT"]
        }
      ]
    }
  }
}
```

### Supabase Redirect URL Config
In the Supabase dashboard under **Authentication > URL Configuration**:
- Site URL: `https://yourapp.com`
- Redirect URLs (add all of these):
  - `myapp://auth/callback`
  - `https://yourapp.com/auth/callback`
  - `exp://localhost:8081/--/auth/callback` (Expo Go dev)

### Handling the Callback in Root Layout
```typescript
// app/_layout.tsx — deep link handling (add inside AuthGate)
import { useEffect } from 'react';
import * as Linking from 'expo-linking';
import { supabase } from '@/lib/supabase';

function useDeepLinkHandler() {
  useEffect(() => {
    const handleUrl = async (url: string) => {
      // OAuth with PKCE: URL contains ?code=...
      if (url.includes('code=')) {
        const { data, error } = await supabase.auth.exchangeCodeForSession(url);
        if (error) {
          console.error('Failed to exchange code for session:', error.message);
        }
        // onAuthStateChange fires automatically with the new session
        return;
      }

      // Implicit flow: URL contains #access_token=...&refresh_token=...
      // (Legacy — PKCE is preferred)
      if (url.includes('access_token=')) {
        const params = new URLSearchParams(url.split('#')[1]);
        const accessToken = params.get('access_token');
        const refreshToken = params.get('refresh_token');
        if (accessToken && refreshToken) {
          await supabase.auth.setSession({
            access_token: accessToken,
            refresh_token: refreshToken,
          });
        }
      }
    };

    // App opened via deep link from a closed state
    Linking.getInitialURL().then((url) => {
      if (url) handleUrl(url);
    });

    // App already open, receives a deep link
    const subscription = Linking.addEventListener('url', ({ url }) => {
      handleUrl(url);
    });

    return () => subscription.remove();
  }, []);
}

// Usage in AuthGate component:
// function AuthGate({ children }) {
//   useDeepLinkHandler();
//   ... rest of component
// }
```

### Required Packages
```bash
npx expo install expo-linking expo-web-browser react-native-url-polyfill
```

### Triggering OAuth from a Screen
```typescript
// app/(auth)/login.tsx — Google OAuth button
import * as WebBrowser from 'expo-web-browser';
import * as Linking from 'expo-linking';
import { supabase } from '@/lib/supabase';

// Required for WebBrowser on Android to properly close the browser tab
WebBrowser.maybeCompleteAuthSession();

async function signInWithGoogle() {
  const redirectTo = Linking.createURL('/auth/callback');

  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo,
      skipBrowserRedirect: true, // We manage the browser ourselves
    },
  });

  if (error) throw error;

  const result = await WebBrowser.openAuthSessionAsync(data.url!, redirectTo);

  if (result.type === 'success') {
    // exchangeCodeForSession is called in the deep link handler
    // onAuthStateChange fires and updates session state
    await supabase.auth.exchangeCodeForSession(result.url);
  }
}
```

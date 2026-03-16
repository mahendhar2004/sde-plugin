# Supabase Patterns Reference

Complete, production-ready TypeScript and SQL patterns for Supabase. Agents read this before generating any Supabase-related code.

---

## 1. Client Initialization (Singleton)

### React Native (Expo) — with SecureStore
```typescript
// lib/supabase.ts
import 'react-native-url-polyfill/auto';
import { createClient } from '@supabase/supabase-js';
import * as SecureStore from 'expo-secure-store';
import { AppState } from 'react-native';
import { Database } from '@/types/supabase';

// SecureStore has a 2048-byte value limit per key.
// Supabase tokens can exceed this, so we chunk large values.
const ExpoSecureStoreAdapter = {
  getItem: async (key: string): Promise<string | null> => {
    const chunksCountStr = await SecureStore.getItemAsync(`${key}_chunks`);
    if (chunksCountStr) {
      const chunksCount = parseInt(chunksCountStr, 10);
      const chunks: string[] = [];
      for (let i = 0; i < chunksCount; i++) {
        const chunk = await SecureStore.getItemAsync(`${key}_chunk_${i}`);
        if (chunk === null) return null;
        chunks.push(chunk);
      }
      return chunks.join('');
    }
    return SecureStore.getItemAsync(key);
  },
  setItem: async (key: string, value: string): Promise<void> => {
    if (value.length <= 1800) {
      await SecureStore.setItemAsync(key, value);
      return;
    }
    // Chunk large values
    const chunkSize = 1800;
    const chunks = Math.ceil(value.length / chunkSize);
    await SecureStore.setItemAsync(`${key}_chunks`, String(chunks));
    for (let i = 0; i < chunks; i++) {
      await SecureStore.setItemAsync(
        `${key}_chunk_${i}`,
        value.slice(i * chunkSize, (i + 1) * chunkSize),
      );
    }
  },
  removeItem: async (key: string): Promise<void> => {
    const chunksCountStr = await SecureStore.getItemAsync(`${key}_chunks`);
    if (chunksCountStr) {
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
    detectSessionInUrl: false,
  },
});

// Refresh token when app comes back to foreground
AppState.addEventListener('change', (state) => {
  if (state === 'active') {
    supabase.auth.startAutoRefresh();
  } else {
    supabase.auth.stopAutoRefresh();
  }
});
```

### Web — with localStorage
```typescript
// lib/supabase.ts
import { createClient } from '@supabase/supabase-js';
import { Database } from '@/types/supabase';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

export const supabase = createClient<Database>(supabaseUrl, supabaseAnonKey, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true,
    // Default storage is localStorage — suitable for web
  },
});
```

---

## 2. Auth Patterns

### Sign Up with Email
```typescript
import { supabase } from '@/lib/supabase';

async function signUp(email: string, password: string, fullName: string) {
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      // Triggers email confirmation if enabled in Supabase dashboard
      emailRedirectTo: 'https://yourapp.com/auth/callback',
      data: {
        // Attached to auth.users.raw_user_meta_data
        // handle_new_user trigger can read these values
        full_name: fullName,
      },
    },
  });

  if (error) throw error;

  // data.user is set; data.session is null until email is confirmed
  // If email confirmation is disabled, data.session is populated immediately
  return data;
}
```

### Sign In with Email
```typescript
async function signInWithEmail(email: string, password: string) {
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (error) throw error;

  // data.session contains access_token and refresh_token
  // data.user contains the authenticated user
  return data;
}
```

### Sign In with OAuth (Google)
```typescript
// Web
async function signInWithGoogle() {
  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: `${window.location.origin}/auth/callback`,
      queryParams: {
        access_type: 'offline',
        prompt: 'consent',
      },
    },
  });

  if (error) throw error;
  // Browser is redirected to Google; no return value to handle here
}

// React Native (Expo) — using expo-web-browser
import * as WebBrowser from 'expo-web-browser';
import * as Linking from 'expo-linking';

async function signInWithGoogleMobile() {
  const redirectTo = Linking.createURL('/auth/callback');

  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo,
      skipBrowserRedirect: true,
    },
  });

  if (error) throw error;

  const result = await WebBrowser.openAuthSessionAsync(
    data.url!,
    redirectTo,
  );

  if (result.type === 'success') {
    const { url } = result;
    await supabase.auth.exchangeCodeForSession(url);
  }
}
```

### Sign Out
```typescript
async function signOut() {
  const { error } = await supabase.auth.signOut();
  if (error) throw error;
}
```

### Get Current User (Typed)
```typescript
import { User } from '@supabase/supabase-js';

// getUser() makes a network request to verify the JWT — use for security-sensitive checks
async function getCurrentUser(): Promise<User | null> {
  const { data: { user }, error } = await supabase.auth.getUser();
  if (error) return null;
  return user;
}

// getSession() reads from local storage — fast but not verified by server
// Use for non-sensitive UI state only
async function getCurrentSession() {
  const { data: { session } } = await supabase.auth.getSession();
  return session;
}
```

### Auth State Listener / onAuthStateChange
```typescript
import { AuthChangeEvent, Session } from '@supabase/supabase-js';

function setupAuthListener(
  callback: (event: AuthChangeEvent, session: Session | null) => void,
) {
  const { data: { subscription } } = supabase.auth.onAuthStateChange(
    (event, session) => {
      // Events:
      //   INITIAL_SESSION   — fired once on init with current session or null
      //   SIGNED_IN         — user signed in or session restored
      //   SIGNED_OUT        — user signed out
      //   TOKEN_REFRESHED   — access token refreshed
      //   USER_UPDATED      — user metadata changed via updateUser()
      //   PASSWORD_RECOVERY — password reset link clicked
      callback(event, session);
    },
  );

  // Return unsubscribe function for cleanup
  return () => subscription.unsubscribe();
}

// Usage in React
useEffect(() => {
  const unsubscribe = setupAuthListener((event, session) => {
    if (event === 'SIGNED_IN' || event === 'INITIAL_SESSION') {
      setUser(session?.user ?? null);
    }
    if (event === 'SIGNED_OUT') {
      setUser(null);
    }
  });
  return unsubscribe;
}, []);
```

### Password Reset Flow
```typescript
// Step 1: Send reset email
async function sendPasswordResetEmail(email: string) {
  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: 'https://yourapp.com/auth/reset-password',
  });
  if (error) throw error;
}

// Step 2: User clicks link in email
// App receives a PASSWORD_RECOVERY event via onAuthStateChange
// The session is populated — user is temporarily authenticated

// Step 3: Update the password while the recovery session is active
async function updatePassword(newPassword: string) {
  const { data, error } = await supabase.auth.updateUser({
    password: newPassword,
  });
  if (error) throw error;
  return data;
}

// In your auth listener, handle PASSWORD_RECOVERY event:
supabase.auth.onAuthStateChange((event, session) => {
  if (event === 'PASSWORD_RECOVERY') {
    // Navigate to reset password form
    router.push('/auth/reset-password');
  }
});
```

### Magic Link
```typescript
async function sendMagicLink(email: string) {
  const { error } = await supabase.auth.signInWithOtp({
    email,
    options: {
      emailRedirectTo: 'https://yourapp.com/auth/callback',
      // Set shouldCreateUser: false to disallow sign-up via magic link
      shouldCreateUser: true,
    },
  });
  if (error) throw error;
}

// For mobile (OTP code via email instead of link):
async function sendMagicLinkOtp(email: string) {
  const { error } = await supabase.auth.signInWithOtp({
    email,
    options: { shouldCreateUser: true },
  });
  if (error) throw error;
}

async function verifyOtp(email: string, token: string) {
  const { data, error } = await supabase.auth.verifyOtp({
    email,
    token,
    type: 'email',
  });
  if (error) throw error;
  return data;
}
```

---

## 3. Database Query Patterns (Typed)

### Type Setup
```typescript
// types/supabase.ts — generated via:
// npx supabase gen types typescript --project-id <id> > types/supabase.ts

import { Database } from '@/types/supabase';

// Derive row types from the generated Database type
type Profile = Database['public']['Tables']['profiles']['Row'];
type ProfileInsert = Database['public']['Tables']['profiles']['Insert'];
type ProfileUpdate = Database['public']['Tables']['profiles']['Update'];

// Derive enum types
type UserRole = Database['public']['Enums']['user_role'];
```

### Select Single Row by ID
```typescript
async function getProfileById(id: string): Promise<Profile> {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', id)
    .single(); // throws PostgrestError with code PGRST116 if 0 rows; error if >1

  if (error) throw error;
  return data;
}

// Prefer maybeSingle() when the row may legitimately not exist
async function findProfileById(id: string): Promise<Profile | null> {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', id)
    .maybeSingle(); // returns null (not an error) when 0 rows

  if (error) throw error;
  return data;
}
```

### Select Rows Filtered by user_id
```typescript
async function getPostsByUser(userId: string): Promise<Post[]> {
  const { data, error } = await supabase
    .from('posts')
    .select('*')
    .eq('user_id', userId)
    .is('deleted_at', null)
    .order('created_at', { ascending: false });

  if (error) throw error;
  return data;
}
```

### Select with JOIN (Nested Select Syntax)
```typescript
// Supabase uses PostgREST nested select — no raw SQL needed for joins

type PostWithAuthor = Database['public']['Tables']['posts']['Row'] & {
  profiles: Pick<Profile, 'id' | 'full_name' | 'avatar_url'> | null;
};

async function getPostsWithAuthors(): Promise<PostWithAuthor[]> {
  const { data, error } = await supabase
    .from('posts')
    .select(`
      *,
      profiles (
        id,
        full_name,
        avatar_url
      )
    `)
    .is('deleted_at', null)
    .order('created_at', { ascending: false });

  if (error) throw error;
  return data as PostWithAuthor[];
}

// Many-to-many: posts with tags via junction table post_tags
type PostWithTags = Database['public']['Tables']['posts']['Row'] & {
  post_tags: Array<{
    tags: Pick<Database['public']['Tables']['tags']['Row'], 'id' | 'name'>;
  }>;
};

async function getPostsWithTags(): Promise<PostWithTags[]> {
  const { data, error } = await supabase
    .from('posts')
    .select(`
      *,
      post_tags (
        tags (
          id,
          name
        )
      )
    `)
    .is('deleted_at', null);

  if (error) throw error;
  return data as PostWithTags[];
}
```

### Insert New Row
```typescript
async function createPost(input: PostInsert): Promise<Post> {
  const { data, error } = await supabase
    .from('posts')
    .insert(input)
    .select()
    .single();

  if (error) throw error;
  return data;
}

// Bulk insert
async function createPosts(inputs: PostInsert[]): Promise<Post[]> {
  const { data, error } = await supabase
    .from('posts')
    .insert(inputs)
    .select();

  if (error) throw error;
  return data;
}
```

### Update Row (RLS handles ownership)
```typescript
async function updateProfile(id: string, updates: ProfileUpdate): Promise<Profile> {
  const { data, error } = await supabase
    .from('profiles')
    .update(updates)
    .eq('id', id)
    .select()
    .single();

  if (error) throw error;
  return data;
}
```

### Soft Delete (set deleted_at)
```typescript
async function softDeletePost(postId: string): Promise<void> {
  const { error } = await supabase
    .from('posts')
    .update({ deleted_at: new Date().toISOString() })
    .eq('id', postId);

  if (error) throw error;
}

// Always filter out soft-deleted rows in queries
const { data } = await supabase
  .from('posts')
  .select('*')
  .is('deleted_at', null);
```

### Paginated List Query with Count
```typescript
interface PaginatedResult<T> {
  data: T[];
  count: number;
  page: number;
  pageSize: number;
  totalPages: number;
}

async function getPaginatedPosts(
  page: number,
  pageSize: number,
): Promise<PaginatedResult<Post>> {
  const from = page * pageSize;
  const to = from + pageSize - 1;

  const { data, error, count } = await supabase
    .from('posts')
    .select('*', { count: 'exact' })
    .is('deleted_at', null)
    .order('created_at', { ascending: false })
    .range(from, to);

  if (error) throw error;

  return {
    data: data ?? [],
    count: count ?? 0,
    page,
    pageSize,
    totalPages: Math.ceil((count ?? 0) / pageSize),
  };
}
```

---

## 4. RLS Policy Templates (SQL)

### User Owns Rows — Full CRUD
```sql
-- Enable RLS on the table first
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

-- SELECT: users can only read their own rows
CREATE POLICY "Users can read own posts"
  ON posts FOR SELECT
  USING (auth.uid() = user_id);

-- INSERT: users can only insert rows where user_id matches their uid
CREATE POLICY "Users can insert own posts"
  ON posts FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- UPDATE: users can only update their own rows
CREATE POLICY "Users can update own posts"
  ON posts FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- DELETE: users can only delete their own rows
CREATE POLICY "Users can delete own posts"
  ON posts FOR DELETE
  USING (auth.uid() = user_id);
```

### Public Read, Auth Write
```sql
ALTER TABLE articles ENABLE ROW LEVEL SECURITY;

-- Anyone (including anonymous) can read
CREATE POLICY "Public read access"
  ON articles FOR SELECT
  USING (true);

-- Only authenticated users can insert
CREATE POLICY "Authenticated users can insert"
  ON articles FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Only the author can update their own articles
CREATE POLICY "Authors can update own articles"
  ON articles FOR UPDATE
  TO authenticated
  USING (auth.uid() = author_id)
  WITH CHECK (auth.uid() = author_id);

-- Only the author can delete their own articles
CREATE POLICY "Authors can delete own articles"
  ON articles FOR DELETE
  TO authenticated
  USING (auth.uid() = author_id);
```

### Team / Org Scoped Access
```sql
-- Schema: organizations, organization_members(org_id, user_id, role), documents(org_id, created_by, ...)
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

-- Helper function: check if current user is a member of an org
-- SECURITY DEFINER prevents recursive RLS evaluation on organization_members
CREATE OR REPLACE FUNCTION is_org_member(org_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM organization_members
    WHERE organization_members.org_id = is_org_member.org_id
      AND organization_members.user_id = auth.uid()
  );
$$;

-- Members can read documents in their orgs
CREATE POLICY "Org members can read documents"
  ON documents FOR SELECT
  USING (is_org_member(org_id));

-- Members can insert documents in their orgs
CREATE POLICY "Org members can insert documents"
  ON documents FOR INSERT
  WITH CHECK (is_org_member(org_id) AND auth.uid() = created_by);

-- Only document owners can update
CREATE POLICY "Document owners can update"
  ON documents FOR UPDATE
  USING (auth.uid() = created_by AND is_org_member(org_id))
  WITH CHECK (auth.uid() = created_by AND is_org_member(org_id));

-- Only document owners can delete
CREATE POLICY "Document owners can delete"
  ON documents FOR DELETE
  USING (auth.uid() = created_by);
```

### Admin Role Bypass (via roles table)
```sql
-- Schema: user_roles(user_id uuid PRIMARY KEY REFERENCES auth.users, role text NOT NULL)
-- Roles: 'admin', 'moderator', 'member'

CREATE OR REPLACE FUNCTION get_user_role()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT role FROM user_roles WHERE user_id = auth.uid() LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION get_user_role() TO authenticated;

-- Admins can read all rows; users can only read their own
CREATE POLICY "Admins read all, users read own"
  ON posts FOR SELECT
  USING (
    get_user_role() = 'admin'
    OR auth.uid() = user_id
  );

-- Admins can update any row; users can only update their own
CREATE POLICY "Admins update all, users update own"
  ON posts FOR UPDATE
  USING (
    get_user_role() = 'admin'
    OR auth.uid() = user_id
  )
  WITH CHECK (
    get_user_role() = 'admin'
    OR auth.uid() = user_id
  );

-- Alternative: using JWT custom claims (set via a Supabase Auth hook or Edge Function)
-- auth.jwt() ->> 'user_role' reads a custom claim baked into the JWT
CREATE POLICY "Admins via JWT claim"
  ON posts FOR SELECT
  USING (
    (auth.jwt() ->> 'user_role') = 'admin'
    OR auth.uid() = user_id
  );
```

---

## 5. Real-time Subscriptions

### Subscribe to Table Changes Filtered by user_id
```typescript
import { RealtimeChannel } from '@supabase/supabase-js';

function subscribeToUserPosts(
  userId: string,
  onInsert: (post: Post) => void,
  onUpdate: (post: Post) => void,
  onDelete: (post: { id: string }) => void,
): RealtimeChannel {
  const channel = supabase
    .channel(`posts:user:${userId}`)
    .on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: 'posts',
        filter: `user_id=eq.${userId}`,
      },
      (payload) => onInsert(payload.new as Post),
    )
    .on(
      'postgres_changes',
      {
        event: 'UPDATE',
        schema: 'public',
        table: 'posts',
        filter: `user_id=eq.${userId}`,
      },
      (payload) => onUpdate(payload.new as Post),
    )
    .on(
      'postgres_changes',
      {
        event: 'DELETE',
        schema: 'public',
        table: 'posts',
        filter: `user_id=eq.${userId}`,
      },
      // payload.old only contains primary key by default unless REPLICA IDENTITY FULL is set
      (payload) => onDelete(payload.old as { id: string }),
    )
    .subscribe();

  return channel;
}
```

### Subscribe to a Specific Row
```typescript
function subscribeToDocument(
  documentId: string,
  onUpdate: (doc: Document) => void,
): RealtimeChannel {
  return supabase
    .channel(`document:${documentId}`)
    .on(
      'postgres_changes',
      {
        event: 'UPDATE',
        schema: 'public',
        table: 'documents',
        filter: `id=eq.${documentId}`,
      },
      (payload) => onUpdate(payload.new as Document),
    )
    .subscribe();
}
```

### Presence (Who's Online)
```typescript
interface UserPresence {
  userId: string;
  username: string;
  onlineAt: string;
}

async function setupPresence(
  roomId: string,
  currentUser: UserPresence,
  onPresenceChange: (users: UserPresence[]) => void,
): Promise<RealtimeChannel> {
  const channel = supabase.channel(`room:${roomId}`, {
    config: { presence: { key: currentUser.userId } },
  });

  channel
    .on('presence', { event: 'sync' }, () => {
      const state = channel.presenceState<UserPresence>();
      const onlineUsers = Object.values(state).flat();
      onPresenceChange(onlineUsers);
    })
    .on('presence', { event: 'join' }, ({ key, newPresences }) => {
      console.log('User joined:', key, newPresences);
    })
    .on('presence', { event: 'leave' }, ({ key, leftPresences }) => {
      console.log('User left:', key, leftPresences);
    })
    .subscribe(async (status) => {
      if (status === 'SUBSCRIBED') {
        await channel.track(currentUser);
      }
    });

  return channel;
}
```

### Unsubscribe on Cleanup (React Hook)
```typescript
import { useEffect, useCallback } from 'react';
import { RealtimeChannel } from '@supabase/supabase-js';

function useRealtimePosts(userId: string, onUpdate: () => void) {
  // Wrap onUpdate in useCallback to avoid re-subscribing on every render
  const stableOnUpdate = useCallback(onUpdate, []);

  useEffect(() => {
    const channel: RealtimeChannel = supabase
      .channel(`posts:${userId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'posts',
          filter: `user_id=eq.${userId}`,
        },
        () => stableOnUpdate(),
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [userId, stableOnUpdate]);
}
```

---

## 6. Storage Patterns

### Upload File (User-Scoped Path)
```typescript
async function uploadAvatar(userId: string, file: File): Promise<string> {
  const fileExt = file.name.split('.').pop() ?? 'jpg';
  const filePath = `${userId}/avatar.${fileExt}`; // user-scoped path enforced by RLS

  const { error } = await supabase.storage
    .from('avatars') // bucket name
    .upload(filePath, file, {
      cacheControl: '3600',
      upsert: true, // overwrite existing file
    });

  if (error) throw error;
  return filePath;
}

// React Native: upload from local URI using base64
import * as FileSystem from 'expo-file-system';

async function uploadAvatarMobile(userId: string, uri: string): Promise<string> {
  const fileExt = uri.split('.').pop()?.toLowerCase() ?? 'jpg';
  const mimeType = fileExt === 'png' ? 'image/png' : 'image/jpeg';
  const filePath = `${userId}/avatar.${fileExt}`;

  const base64 = await FileSystem.readAsStringAsync(uri, {
    encoding: FileSystem.EncodingType.Base64,
  });

  const arrayBuffer = Uint8Array.from(atob(base64), (c) => c.charCodeAt(0));

  const { error } = await supabase.storage
    .from('avatars')
    .upload(filePath, arrayBuffer, {
      contentType: mimeType,
      upsert: true,
    });

  if (error) throw error;
  return filePath;
}
```

### Get Public URL
```typescript
function getAvatarPublicUrl(filePath: string): string {
  const { data } = supabase.storage
    .from('avatars')
    .getPublicUrl(filePath);

  return data.publicUrl;
}
```

### Get Signed URL (Private Buckets)
```typescript
async function getSignedUrl(
  bucket: string,
  filePath: string,
  expiresInSeconds = 3600,
): Promise<string> {
  const { data, error } = await supabase.storage
    .from(bucket)
    .createSignedUrl(filePath, expiresInSeconds);

  if (error) throw error;
  return data.signedUrl;
}

// Batch signed URLs for multiple files
async function getSignedUrls(
  bucket: string,
  filePaths: string[],
  expiresInSeconds = 3600,
): Promise<Array<{ path: string; signedUrl: string }>> {
  const { data, error } = await supabase.storage
    .from(bucket)
    .createSignedUrls(filePaths, expiresInSeconds);

  if (error) throw error;
  return data.map((item) => ({ path: item.path, signedUrl: item.signedUrl ?? '' }));
}
```

### Delete File
```typescript
async function deleteFiles(bucket: string, filePaths: string[]): Promise<void> {
  const { error } = await supabase.storage
    .from(bucket)
    .remove(filePaths);

  if (error) throw error;
}
```

### List Files in Folder
```typescript
async function listUserFiles(userId: string) {
  const { data, error } = await supabase.storage
    .from('documents')
    .list(userId, {
      limit: 100,
      offset: 0,
      sortBy: { column: 'created_at', order: 'desc' },
    });

  if (error) throw error;
  return data;
}
```

### Storage RLS Policy (SQL)
```sql
-- Storage policies apply to the storage.objects table.
-- Bucket: avatars (public bucket — anyone can read, only owner can write)
-- Path convention: {userId}/filename.ext

-- Allow public read from the avatars bucket
CREATE POLICY "Public avatar read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

-- Authenticated users may upload to their own folder only
CREATE POLICY "Users upload own avatar"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Authenticated users may overwrite their own files
CREATE POLICY "Users update own avatar"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Authenticated users may delete their own files
CREATE POLICY "Users delete own avatar"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
```

---

## 7. Edge Functions

### Complete Edge Function Template (with JWT Verification)
```typescript
// supabase/functions/send-notification/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';

interface RequestBody {
  recipientId: string;
  message: string;
}

interface Notification {
  id: string;
  user_id: string;
  message: string;
  sent_by: string;
  created_at: string;
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Require Authorization header
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // Create a client with the user's JWT — RLS applies for this client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );

    // Verify the token and get the calling user
    const { data: { user }, error: authError } = await supabaseClient.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // Use service-role client for operations that bypass RLS
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const body: RequestBody = await req.json();

    const { data: notification, error } = await supabaseAdmin
      .from('notifications')
      .insert({
        user_id: body.recipientId,
        message: body.message,
        sent_by: user.id,
      })
      .select()
      .single();

    if (error) throw error;

    return new Response(
      JSON.stringify({ success: true, notification }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Internal server error';
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
```

### Shared CORS Utility
```typescript
// supabase/functions/_shared/cors.ts
export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS, PUT, DELETE',
};
```

### Calling an Edge Function from Client
```typescript
interface SendNotificationResponse {
  success: boolean;
  notification: { id: string; message: string };
}

async function sendNotification(
  recipientId: string,
  message: string,
): Promise<SendNotificationResponse> {
  const { data, error } = await supabase.functions.invoke<SendNotificationResponse>(
    'send-notification',
    {
      body: { recipientId, message },
    },
  );

  if (error) throw error;
  return data!;
}
```

---

## 8. Database Functions & Triggers (SQL)

### updated_at Trigger (Apply to All Tables)
```sql
-- Step 1: Create the trigger function once, reuse across tables
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- Step 2: Apply to each table that has an updated_at column
-- Pattern: copy this block and change the table name

CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON posts
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON documents
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
```

### handle_new_user Trigger (Create Profile on Signup)
```sql
-- Called automatically after a new row is inserted into auth.users
-- SECURITY DEFINER: runs with the function owner's privileges, not the caller's
-- SET search_path = public: prevents search path injection

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, avatar_url, created_at, updated_at)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data ->> 'full_name',
    NEW.raw_user_meta_data ->> 'avatar_url',
    NOW(),
    NOW()
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();
```

### get_user_role() Function
```sql
-- Returns the role of the currently authenticated user.
-- Used in RLS policies: get_user_role() = 'admin'
-- STABLE: tells Postgres the function returns the same result within a single query

CREATE OR REPLACE FUNCTION get_user_role()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT role
  FROM user_roles
  WHERE user_id = auth.uid()
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION get_user_role() TO authenticated;
```

---

## 9. React Query + Supabase Integration

### Query Key Factory
```typescript
// lib/queryKeys.ts
export const queryKeys = {
  profiles: {
    all: ['profiles'] as const,
    detail: (id: string) => ['profiles', 'detail', id] as const,
  },
  posts: {
    all: ['posts'] as const,
    lists: () => ['posts', 'list'] as const,
    list: (filters: Record<string, unknown>) => ['posts', 'list', filters] as const,
    detail: (id: string) => ['posts', 'detail', id] as const,
    byUser: (userId: string) => ['posts', 'list', { userId }] as const,
  },
  documents: {
    all: ['documents'] as const,
    byOrg: (orgId: string) => ['documents', 'list', { orgId }] as const,
    detail: (id: string) => ['documents', 'detail', id] as const,
  },
};
```

### useQuery Wrapper for Supabase
```typescript
// hooks/useProfile.ts
import { useQuery } from '@tanstack/react-query';
import { supabase } from '@/lib/supabase';
import { queryKeys } from '@/lib/queryKeys';
import { Database } from '@/types/supabase';

type Profile = Database['public']['Tables']['profiles']['Row'];

async function fetchProfile(id: string): Promise<Profile> {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', id)
    .single();

  if (error) throw error;
  return data;
}

export function useProfile(id: string | undefined) {
  return useQuery({
    queryKey: queryKeys.profiles.detail(id ?? ''),
    queryFn: () => fetchProfile(id!),
    staleTime: 1000 * 60 * 5, // 5 minutes
    enabled: Boolean(id),
  });
}
```

### useMutation Wrapper for Supabase
```typescript
// hooks/useUpdateProfile.ts
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/lib/supabase';
import { queryKeys } from '@/lib/queryKeys';
import { Database } from '@/types/supabase';

type ProfileUpdate = Database['public']['Tables']['profiles']['Update'];
type Profile = Database['public']['Tables']['profiles']['Row'];

async function updateProfile(id: string, updates: ProfileUpdate): Promise<Profile> {
  const { data, error } = await supabase
    .from('profiles')
    .update(updates)
    .eq('id', id)
    .select()
    .single();

  if (error) throw error;
  return data;
}

export function useUpdateProfile(id: string) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (updates: ProfileUpdate) => updateProfile(id, updates),
    onSuccess: (updatedProfile) => {
      // Write updated data directly into the cache — no refetch needed
      queryClient.setQueryData(queryKeys.profiles.detail(id), updatedProfile);
    },
    onError: (error) => {
      console.error('Failed to update profile:', error);
    },
  });
}
```

### Optimistic Update Pattern
```typescript
// hooks/useTogglePostLike.ts
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/lib/supabase';
import { queryKeys } from '@/lib/queryKeys';

interface Post {
  id: string;
  likes_count: number;
  liked_by_user: boolean;
}

export function useTogglePostLike(postId: string) {
  const queryClient = useQueryClient();
  const queryKey = queryKeys.posts.detail(postId);

  return useMutation({
    mutationFn: async ({ liked }: { liked: boolean }) => {
      if (liked) {
        const { error } = await supabase
          .from('post_likes')
          .insert({ post_id: postId });
        if (error) throw error;
      } else {
        const { error } = await supabase
          .from('post_likes')
          .delete()
          .eq('post_id', postId);
        if (error) throw error;
      }
    },
    onMutate: async ({ liked }) => {
      // Cancel any in-flight refetches so they don't overwrite the optimistic update
      await queryClient.cancelQueries({ queryKey });

      // Snapshot current value for rollback
      const previousPost = queryClient.getQueryData<Post>(queryKey);

      // Apply optimistic update immediately
      queryClient.setQueryData<Post>(queryKey, (old) => {
        if (!old) return old;
        return {
          ...old,
          liked_by_user: liked,
          likes_count: liked ? old.likes_count + 1 : old.likes_count - 1,
        };
      });

      return { previousPost };
    },
    onError: (_err, _variables, context) => {
      // Roll back to snapshot on error
      if (context?.previousPost) {
        queryClient.setQueryData(queryKey, context.previousPost);
      }
    },
    onSettled: () => {
      // Always sync with server after mutation settles (success or error)
      queryClient.invalidateQueries({ queryKey });
    },
  });
}
```

---

## 10. Error Handling

### Typed Supabase Error Handling
```typescript
import { PostgrestError, AuthError } from '@supabase/supabase-js';

function isPostgrestError(error: unknown): error is PostgrestError {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    'message' in error &&
    'details' in error
  );
}

function isAuthError(error: unknown): error is AuthError {
  return error instanceof AuthError;
}

function handleSupabaseError(error: PostgrestError | AuthError | Error): never {
  if (isAuthError(error)) {
    if (error.message.includes('Invalid login credentials')) {
      throw new Error('Invalid email or password.');
    }
    if (error.message.includes('Email not confirmed')) {
      throw new Error('Please confirm your email address before logging in.');
    }
    throw new Error(`Authentication error: ${error.message}`);
  }

  if (isPostgrestError(error)) {
    switch (error.code) {
      case '23505': // unique_violation
        throw new Error('A record with this value already exists.');
      case '23503': // foreign_key_violation
        throw new Error('Referenced record does not exist.');
      case '42501': // insufficient_privilege — RLS blocked the operation
        throw new Error('You do not have permission to perform this action.');
      case 'PGRST116': // .single() returned 0 rows
        throw new Error('Record not found.');
      default:
        throw new Error(`Database error: ${error.message}`);
    }
  }

  throw error;
}
```

### Network vs Auth vs RLS Error Distinction
```typescript
import { AuthApiError } from '@supabase/supabase-js';

type SupabaseErrorKind = 'network' | 'auth' | 'rls' | 'not_found' | 'conflict' | 'unknown';

function classifyError(error: unknown): SupabaseErrorKind {
  if (error instanceof TypeError && error.message === 'Failed to fetch') {
    return 'network';
  }
  if (error instanceof AuthApiError) {
    return 'auth';
  }
  if (isPostgrestError(error)) {
    if (error.code === '42501') return 'rls';
    if (error.code === 'PGRST116') return 'not_found';
    if (error.code === '23505') return 'conflict';
  }
  return 'unknown';
}

// Usage in query function
async function safeGetProfile(id: string): Promise<Profile | null> {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', id)
    .single();

  if (error) {
    const kind = classifyError(error);
    if (kind === 'not_found') return null;
    if (kind === 'rls') throw new Error('Access denied.');
    if (kind === 'network') throw new Error('No internet connection.');
    throw error;
  }

  return data;
}
```

### Error Boundary for Supabase Auth Failures (React)
```typescript
// components/AuthErrorBoundary.tsx
import React, { Component, ReactNode } from 'react';
import { AuthError } from '@supabase/supabase-js';

interface Props {
  children: ReactNode;
  onAuthError?: () => void;
}

interface State {
  hasError: boolean;
  isAuthError: boolean;
}

export class AuthErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false, isAuthError: false };
  }

  static getDerivedStateFromError(error: unknown): State {
    return {
      hasError: true,
      isAuthError: error instanceof AuthError,
    };
  }

  componentDidCatch(error: unknown) {
    if (error instanceof AuthError) {
      this.props.onAuthError?.();
    }
  }

  render() {
    if (this.state.hasError) {
      if (this.state.isAuthError) {
        return (
          <div className="flex items-center justify-center h-screen">
            <div className="text-center">
              <h2 className="text-xl font-semibold">Session expired</h2>
              <p className="text-gray-500 mt-2">Please sign in again to continue.</p>
              <button
                className="mt-4 px-4 py-2 bg-blue-600 text-white rounded"
                onClick={() => {
                  this.setState({ hasError: false, isAuthError: false });
                  window.location.href = '/login';
                }}
              >
                Go to Login
              </button>
            </div>
          </div>
        );
      }

      return (
        <div className="p-4 text-red-600">
          Something went wrong. Please refresh the page.
        </div>
      );
    }

    return this.props.children;
  }
}
```

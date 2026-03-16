# React Patterns Reference

Quick reference for React 18 + TypeScript + Tailwind + TanStack Query patterns. Agents read this before generating frontend code.

---

## Folder Conventions
```
src/
├── components/ui/         # Reusable base components (Button, Input, Modal, Badge, etc.)
├── components/layout/     # App shells (AppLayout, Sidebar, Navbar)
├── components/[feature]/  # Feature-specific composed components
├── pages/                 # Route-level components — thin shells, compose others
├── hooks/                 # Custom hooks: useAuth, use[Feature], usePagination
├── services/api.ts        # Axios instance + all API call functions (one object per resource)
├── store/                 # Zustand stores (one file per domain)
├── types/                 # TypeScript types and interfaces (mirrors backend types)
└── utils/                 # Pure functions, formatters, validators
```

---

## API Service Pattern
```typescript
// services/api.ts — resource-grouped functions
export const usersApi = {
  list: (params: UserQueryParams) =>
    api.get<PaginatedResponse<User>>('/users', { params }).then(r => r.data),
  getById: (id: string) =>
    api.get<User>(`/users/${id}`).then(r => r.data),
  create: (data: CreateUserDto) =>
    api.post<User>('/users', data).then(r => r.data),
  update: (id: string, data: UpdateUserDto) =>
    api.patch<User>(`/users/${id}`, data).then(r => r.data),
  delete: (id: string) =>
    api.delete(`/users/${id}`),
};
```

---

## Query Key Factory Pattern
```typescript
// Centralized query keys — prevents cache key collisions
export const userKeys = {
  all: ['users'] as const,
  lists: () => [...userKeys.all, 'list'] as const,
  list: (params: UserQueryParams) => [...userKeys.lists(), params] as const,
  details: () => [...userKeys.all, 'detail'] as const,
  detail: (id: string) => [...userKeys.details(), id] as const,
};

// Usage
useQuery({ queryKey: userKeys.detail(userId), queryFn: () => usersApi.getById(userId) })
queryClient.invalidateQueries({ queryKey: userKeys.lists() })
```

---

## Zustand Store Pattern
```typescript
// store/auth.store.ts
interface AuthState {
  user: User | null;
  isAuthenticated: boolean;
  login: (user: User, tokens: TokenPair) => void;
  logout: () => void;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      user: null,
      isAuthenticated: false,
      login: (user, tokens) => {
        localStorage.setItem('access_token', tokens.accessToken);
        localStorage.setItem('refresh_token', tokens.refreshToken);
        set({ user, isAuthenticated: true });
      },
      logout: () => {
        localStorage.removeItem('access_token');
        localStorage.removeItem('refresh_token');
        set({ user: null, isAuthenticated: false });
      },
    }),
    { name: 'auth-storage', partialize: (state) => ({ user: state.user }) }
  )
);
```

---

## Protected Route Pattern
```typescript
// components/layout/ProtectedRoute.tsx
export function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const isAuthenticated = useAuthStore(s => s.isAuthenticated);
  const location = useLocation();

  if (!isAuthenticated) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }
  return <>{children}</>;
}
```

---

## Component with All States
```typescript
// Always handle: loading, error, empty, success
export function ItemsList() {
  const { data, isLoading, error, refetch } = useItems();

  if (isLoading) return <ItemsListSkeleton />;
  if (error) return <ErrorState message="Failed to load items" onRetry={refetch} />;
  if (!data?.items.length) return <EmptyState message="No items yet" action={{ label: 'Create item', href: '/items/new' }} />;

  return (
    <ul className="space-y-3">
      {data.items.map(item => <ItemCard key={item.id} item={item} />)}
    </ul>
  );
}
```

---

## Optimistic Update Pattern
```typescript
const deleteItem = useMutation({
  mutationFn: (id: string) => itemsApi.delete(id),
  onMutate: async (deletedId) => {
    // Cancel in-flight queries
    await queryClient.cancelQueries({ queryKey: itemKeys.lists() });
    // Snapshot current state for rollback
    const previous = queryClient.getQueryData(itemKeys.lists());
    // Optimistically update
    queryClient.setQueryData(itemKeys.lists(), (old: Item[]) =>
      old?.filter(item => item.id !== deletedId)
    );
    return { previous };
  },
  onError: (_err, _id, context) => {
    // Rollback on error
    queryClient.setQueryData(itemKeys.lists(), context?.previous);
    toast.error('Failed to delete item');
  },
  onSettled: () => {
    queryClient.invalidateQueries({ queryKey: itemKeys.lists() });
  },
});
```

---

## Error Boundary
```typescript
// components/ErrorBoundary.tsx
export class ErrorBoundary extends React.Component<
  { children: ReactNode; fallback?: ReactNode },
  { hasError: boolean }
> {
  state = { hasError: false };

  static getDerivedStateFromError() { return { hasError: true }; }

  componentDidCatch(error: Error) {
    Sentry.captureException(error);
  }

  render() {
    if (this.state.hasError) {
      return this.props.fallback ?? (
        <div className="flex flex-col items-center justify-center p-8 text-center">
          <p className="text-lg font-semibold text-gray-900">Something went wrong</p>
          <button onClick={() => this.setState({ hasError: false })} className="mt-4 btn-primary">
            Try again
          </button>
        </div>
      );
    }
    return this.props.children;
  }
}
```

---

## Reusable UI Components (always build these)

```typescript
// Button with loading state
interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'danger' | 'ghost';
  size?: 'sm' | 'md' | 'lg';
  isLoading?: boolean;
}
// Implement with Tailwind variants and disabled+loading states

// Input with error display
interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label: string;
  error?: string;
  hint?: string;
}
// Implement with label, input, error message (red text), hint (gray text)

// Modal/Dialog
// Use HTML dialog element or headlessui/dialog
// Always trap focus, close on Escape, close on overlay click (optional)

// Skeleton (loading placeholder)
// Use animate-pulse with bg-gray-200 rounded blocks
```

---

## React Router v6 Layout Pattern
```typescript
// App.tsx
<BrowserRouter>
  <Routes>
    <Route path="/login" element={<LoginPage />} />
    <Route path="/register" element={<RegisterPage />} />
    <Route element={<ProtectedRoute><AppLayout /></ProtectedRoute>}>
      <Route path="/" element={<DashboardPage />} />
      <Route path="/users" element={<UsersPage />} />
      <Route path="/users/:id" element={<UserDetailPage />} />
    </Route>
    <Route path="*" element={<NotFoundPage />} />
  </Routes>
</BrowserRouter>
```

import { create } from "zustand";

export interface SessionUser {
  email: string;
  name: string;
  role: string;
}

export interface Session {
  token: string;
  user: SessionUser;
  tenant: { id: string; name: string };
}

const KEY = "kairos.session";

function read(): Session | null {
  try {
    const raw = localStorage.getItem(KEY);
    return raw ? (JSON.parse(raw) as Session) : null;
  } catch {
    return null;
  }
}

interface SessionState {
  session: Session | null;
  signIn: (s: Session) => void;
  signOut: () => void;
}

/** Demo sign-in session. Production would use the customer's SSO (OIDC/SAML). */
export const useSession = create<SessionState>((set) => ({
  session: read(),
  signIn: (session) => {
    try {
      localStorage.setItem(KEY, JSON.stringify(session));
    } catch {
      /* still signed in for this tab */
    }
    set({ session });
  },
  signOut: () => {
    try {
      localStorage.removeItem(KEY);
    } catch {
      /* ignore */
    }
    set({ session: null });
  },
}));

/** Token for API and WebSocket calls: the signed-in session first, then the build-time token. */
export const authToken = (): string => useSession.getState().session?.token || import.meta.env.VITE_API_TOKEN || "";

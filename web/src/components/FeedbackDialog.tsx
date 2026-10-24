import * as Dialog from "@radix-ui/react-dialog";
import { CheckCircle2, Loader2, MessageSquarePlus, Star, X } from "lucide-react";
import { useState, type ReactNode } from "react";
import { useLocation } from "react-router-dom";

import { api, type FeedbackIn } from "@/lib/api/client";
import { useSession } from "@/lib/session";

const CATEGORIES: { value: FeedbackIn["category"]; label: string }[] = [
  { value: "bug", label: "Something broke" },
  { value: "idea", label: "Idea" },
  { value: "data", label: "Data or model" },
  { value: "other", label: "Other" },
];

/** Feedback from any signed-in user; stored by the backend (feedback.jsonl). */
export function FeedbackDialog({ trigger }: { trigger?: ReactNode }) {
  const loc = useLocation();
  const user = useSession((s) => s.session?.user);
  const [open, setOpen] = useState(false);
  const [category, setCategory] = useState<FeedbackIn["category"]>("idea");
  const [rating, setRating] = useState<number | null>(null);
  const [message, setMessage] = useState("");
  const [state, setState] = useState<"idle" | "sending" | "sent" | "error">("idle");
  const reactor = loc.pathname.match(/\/reactors\/([^/]+)/)?.[1] ?? null;

  const reset = () => {
    setCategory("idea");
    setRating(null);
    setMessage("");
    setState("idle");
  };

  const submit = async () => {
    if (!message.trim()) return;
    setState("sending");
    try {
      await api.feedback({
        category,
        rating,
        message: message.trim(),
        source: "web",
        reactor_id: reactor ? decodeURIComponent(reactor) : null,
        page: loc.pathname,
        user: user ? `${user.name} (${user.role})` : null,
      });
      setState("sent");
    } catch {
      setState("error");
    }
  };

  return (
    <Dialog.Root
      open={open}
      onOpenChange={(o) => {
        setOpen(o);
        if (!o) reset();
      }}
    >
      <Dialog.Trigger asChild>
        {trigger ?? (
          <button className="flex w-full items-center gap-2.5 rounded-control px-3 py-2 text-sm text-text-secondary hover:bg-bg-elevated hover:text-text-primary">
            <MessageSquarePlus size={16} /> Send feedback
          </button>
        )}
      </Dialog.Trigger>
      <Dialog.Portal>
        <Dialog.Overlay className="fixed inset-0 z-50 bg-black/50 backdrop-blur-sm" />
        <Dialog.Content className="fixed left-1/2 top-1/2 z-50 w-[min(480px,calc(100vw-32px))] -translate-x-1/2 -translate-y-1/2 rounded-card border border-border-strong bg-bg-elevated p-5 shadow-2xl">
          <div className="flex items-start justify-between gap-4">
            <div>
              <Dialog.Title className="display text-lg font-semibold">Send feedback</Dialog.Title>
              <Dialog.Description className="mt-1 text-sm text-text-secondary">
                Tell the Kairos team what works, what doesn't, or what you need on shift.
              </Dialog.Description>
            </div>
            <Dialog.Close aria-label="Close" className="rounded-control p-1 text-text-muted hover:bg-bg-surface hover:text-text-primary">
              <X size={16} />
            </Dialog.Close>
          </div>

          {state === "sent" ? (
            <div className="flex flex-col items-center gap-2 py-8 text-center">
              <CheckCircle2 size={36} style={{ color: "var(--color-state-healthy)" }} />
              <div className="font-semibold">Thanks, your feedback reached the team.</div>
              <Dialog.Close className="mt-3 rounded-control border border-border-strong px-4 py-2 text-sm hover:bg-bg-surface">Close</Dialog.Close>
            </div>
          ) : (
            <form
              className="mt-4 space-y-4"
              onSubmit={(e) => {
                e.preventDefault();
                void submit();
              }}
            >
              <fieldset>
                <legend className="mb-1.5 text-xs font-medium text-text-muted">Topic</legend>
                <div className="flex flex-wrap gap-1.5">
                  {CATEGORIES.map((c) => (
                    <button
                      type="button"
                      key={c.value}
                      onClick={() => setCategory(c.value)}
                      aria-pressed={category === c.value}
                      className={`rounded-full border px-3 py-1 text-xs ${category === c.value ? "border-accent-500 bg-accent-glow text-text-primary" : "border-border-subtle text-text-secondary hover:text-text-primary"}`}
                    >
                      {c.label}
                    </button>
                  ))}
                </div>
              </fieldset>
              <fieldset>
                <legend className="mb-1.5 text-xs font-medium text-text-muted">How useful is Kairos so far? (optional)</legend>
                <div className="flex gap-1">
                  {[1, 2, 3, 4, 5].map((n) => (
                    <button
                      type="button"
                      key={n}
                      aria-label={`${n} of 5`}
                      onClick={() => setRating(rating === n ? null : n)}
                      className="rounded p-0.5"
                    >
                      <Star
                        size={22}
                        fill={rating !== null && n <= rating ? "var(--color-state-watch)" : "none"}
                        stroke={rating !== null && n <= rating ? "var(--color-state-watch)" : "var(--color-text-muted)"}
                      />
                    </button>
                  ))}
                </div>
              </fieldset>
              <label className="block">
                <span className="mb-1.5 block text-xs font-medium text-text-muted">Message</span>
                <textarea
                  value={message}
                  onChange={(e) => setMessage(e.target.value.slice(0, 2000))}
                  rows={5}
                  required
                  placeholder={reactor ? `About ${decodeURIComponent(reactor)}...` : "What should we know?"}
                  className="w-full resize-none rounded-control border border-border-subtle bg-bg-surface px-3 py-2 text-sm outline-none focus:border-accent-500"
                />
                <span className="mt-1 block text-right text-[11px] text-text-muted">{message.length} / 2000</span>
              </label>
              {state === "error" && (
                <div className="text-sm" style={{ color: "var(--color-state-alarm)" }}>
                  Could not send. Check the connection and try again.
                </div>
              )}
              <div className="flex justify-end gap-2">
                <Dialog.Close type="button" className="rounded-control px-4 py-2 text-sm text-text-secondary hover:bg-bg-surface">
                  Cancel
                </Dialog.Close>
                <button
                  type="submit"
                  disabled={!message.trim() || state === "sending"}
                  className="flex items-center gap-2 rounded-control bg-accent-500 px-4 py-2 text-sm font-semibold text-bg-base hover:bg-accent-600 disabled:opacity-50"
                >
                  {state === "sending" && <Loader2 size={14} className="animate-spin" />} Send
                </button>
              </div>
            </form>
          )}
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}

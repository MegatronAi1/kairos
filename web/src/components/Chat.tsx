import { Loader2, Send } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import Markdown from "react-markdown";

import { EvidenceChip } from "@/components/primitives";
import { chatStream } from "@/lib/api/client";

interface Msg {
  role: "user" | "assistant";
  content: string;
  evidence?: string[];
  error?: boolean;
}

const TOOL_LABEL: Record<string, string> = {
  get_reactor_state: "reading live sensors",
  predict_final_yield: "checking the yield forecast",
  explain_drivers: "working out the drivers",
  diagnose_alarm: "checking the fault detector",
  recommend_settings: "looking for a better setpoint",
  simulate_what_if: "simulating the change",
  estimate_point_of_no_return: "estimating the point of no return",
  get_model_evidence: "checking model accuracy",
  get_data_provenance: "checking data provenance",
};

/** Ask Kairos: streamed answers with evidence chips. Every number comes from engine tools. */
export function Chat({ reactorId, suggestions }: { reactorId?: string; suggestions: string[] }) {
  const [messages, setMessages] = useState<Msg[]>([]);
  const [input, setInput] = useState("");
  const [busy, setBusy] = useState(false);
  const [activity, setActivity] = useState<string | null>(null);
  const abort = useRef<AbortController | null>(null);
  const end = useRef<HTMLDivElement>(null);

  useEffect(() => {
    end.current?.scrollIntoView?.({ block: "end" });
  }, [messages, activity]);
  useEffect(() => {
    return () => {
      abort.current?.abort();
    };
  }, []);

  async function send(text: string) {
    const q = text.trim();
    if (!q || busy) return;
    const history: Msg[] = [...messages, { role: "user", content: q }];
    setMessages([...history, { role: "assistant", content: "" }]);
    setInput("");
    setBusy(true);
    setActivity("thinking");
    abort.current = new AbortController();
    const update = (fn: (m: Msg) => Msg) =>
      setMessages((ms) => [...ms.slice(0, -1), fn(ms[ms.length - 1]!)]);
    try {
      const payload = history.filter((m) => !m.error).map(({ role, content }) => ({ role, content }));
      for await (const ev of chatStream(payload, reactorId, abort.current.signal)) {
        if (ev.type === "text") {
          setActivity(null);
          update((m) => ({ ...m, content: m.content + ev.delta }));
        } else if (ev.type === "tool") setActivity(TOOL_LABEL[ev.name] ?? "working");
        else if (ev.type === "evidence") update((m) => ({ ...m, evidence: ev.items }));
        else if (ev.type === "error") update((m) => ({ ...m, content: ev.message, error: true }));
      }
    } catch {
      update((m) => ({ ...m, content: "Could not reach the copilot.", error: true }));
    } finally {
      setBusy(false);
      setActivity(null);
    }
  }

  return (
    <div className="flex h-full min-h-0 flex-col">
      <div className="min-h-0 flex-1 space-y-3 overflow-y-auto pr-1" aria-live="polite">
        {messages.length === 0 && (
          <div className="space-y-2">
            <p className="text-sm text-text-muted">Ask about drift, drivers, forecasts or model accuracy.</p>
            {suggestions.map((s) => (
              <button
                key={s}
                onClick={() => send(s)}
                className="block w-full rounded-control border border-border-subtle px-3 py-2 text-left text-sm text-text-secondary hover:border-border-strong hover:text-text-primary"
              >
                {s}
              </button>
            ))}
          </div>
        )}
        {messages.map((m, i) =>
          m.role === "user" ? (
            <div key={i} className="ml-8 rounded-card bg-bg-elevated px-3 py-2 text-sm">
              {m.content}
            </div>
          ) : (
            <div key={i} className={`text-sm leading-relaxed ${m.error ? "text-text-secondary" : ""}`}>
              {m.content ? (
                <div className="prose-kairos">
                  <Markdown>{m.content}</Markdown>
                </div>
              ) : null}
              {m.evidence && m.evidence.length > 0 && (
                <div className="mt-2 flex flex-wrap items-center gap-1.5">
                  <span className="text-xs text-text-muted">Based on</span>
                  {m.evidence.map((e) => (
                    <EvidenceChip key={e} source={e} />
                  ))}
                </div>
              )}
            </div>
          ),
        )}
        {activity && (
          <div className="flex items-center gap-2 text-sm text-text-muted">
            <Loader2 size={14} className="animate-spin" aria-hidden /> Kairos is {activity}…
          </div>
        )}
        <div ref={end} />
      </div>
      <form
        className="mt-3 flex gap-2"
        onSubmit={(e) => {
          e.preventDefault();
          void send(input);
        }}
      >
        <input
          value={input}
          onChange={(e) => setInput(e.target.value)}
          placeholder="Ask Kairos…"
          aria-label="Ask Kairos"
          maxLength={2000}
          className="min-w-0 flex-1 rounded-control border border-border-subtle bg-bg-inset px-3 py-2 text-sm outline-none focus:border-accent-500"
        />
        <button
          type="submit"
          disabled={busy || !input.trim()}
          aria-label="Send"
          className="rounded-control bg-accent-500 px-3 text-bg-base disabled:opacity-40"
        >
          <Send size={16} />
        </button>
      </form>
    </div>
  );
}

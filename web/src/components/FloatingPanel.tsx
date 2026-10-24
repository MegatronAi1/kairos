import { motion, useDragControls } from "framer-motion";
import { ChevronDown, GripVertical, X } from "lucide-react";
import { useState, type CSSProperties, type ReactNode, type RefObject } from "react";

/**
 * Frosted-glass panel that floats over the 3D stage. Draggable by its header,
 * collapsible, closable. When `floating` is false (small screens) it renders as
 * a normal static card so nothing ever overlaps.
 */
export function FloatingPanel({
  title,
  icon,
  children,
  position,
  bounds,
  floating,
  width = 320,
  onClose,
  resetKey,
  defaultOpen = true,
}: {
  title: string;
  icon?: ReactNode;
  children: ReactNode;
  position: CSSProperties;
  bounds: RefObject<HTMLElement>;
  floating: boolean;
  width?: number;
  onClose?: () => void;
  resetKey?: number;
  defaultOpen?: boolean;
}) {
  const [open, setOpen] = useState(defaultOpen);
  const controls = useDragControls();
  const header = (
    <div
      className={`flex items-center gap-2 px-3 py-2 ${floating ? "cursor-grab active:cursor-grabbing" : ""}`}
      onPointerDown={(e) => floating && controls.start(e)}
    >
      {floating && <GripVertical size={14} className="text-text-muted" aria-hidden />}
      {icon && <span className="text-text-secondary">{icon}</span>}
      <h2 className="flex-1 text-sm font-semibold">{title}</h2>
      <button
        onClick={() => setOpen((o) => !o)}
        onPointerDown={(e) => e.stopPropagation()}
        aria-label={open ? `Collapse ${title}` : `Expand ${title}`}
        className="rounded p-1 text-text-muted hover:bg-bg-elevated hover:text-text-primary"
      >
        <ChevronDown size={15} className={`transition-transform ${open ? "" : "-rotate-90"}`} />
      </button>
      {onClose && floating && (
        <button
          onClick={onClose}
          onPointerDown={(e) => e.stopPropagation()}
          aria-label={`Hide ${title}`}
          className="rounded p-1 text-text-muted hover:bg-bg-elevated hover:text-text-primary"
        >
          <X size={14} />
        </button>
      )}
    </div>
  );
  const body = open && <div className="border-t border-border-subtle px-3 pb-3 pt-2">{children}</div>;

  if (!floating) {
    return (
      <section className="rounded-card border border-border-subtle bg-bg-surface">
        {header}
        {body}
      </section>
    );
  }
  return (
    <motion.section
      key={resetKey}
      drag
      dragControls={controls}
      dragListener={false}
      dragMomentum={false}
      dragConstraints={bounds}
      dragElastic={0.04}
      className="glass absolute z-10 rounded-card"
      style={{ ...position, width }}
      initial={{ opacity: 0, scale: 0.98 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{ duration: 0.2 }}
    >
      {header}
      {body}
    </motion.section>
  );
}

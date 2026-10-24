"use client";

import { CheckCircle2, CircleAlert } from "lucide-react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useEffect, useRef, useState, useTransition } from "react";
import { useFormStatus } from "react-dom";

// Disables itself while its form is submitting, so a double click can never
// send the same decision twice.
export function SubmitButton({
  children,
  className = "btn",
  confirm,
  disabled,
  name,
  value,
  formId,
}: {
  children: React.ReactNode;
  className?: string;
  confirm?: string;
  disabled?: boolean;
  name?: string;
  value?: string;
  formId?: string;
}) {
  const { pending } = useFormStatus();
  return (
    <button
      type="submit"
      form={formId}
      name={name}
      value={value}
      className={`${className}${pending ? " is-pending" : ""}`}
      disabled={disabled || pending}
      aria-busy={pending || undefined}
      onClick={(event) => {
        if (confirm && !window.confirm(confirm)) event.preventDefault();
      }}
    >
      {children}
    </button>
  );
}

// Server actions report outcomes through ?admin_success / ?admin_error. The
// toast strips them with history.replaceState, which updates the URL without
// another server render.
export function FlashToast() {
  const params = useSearchParams();
  const error = params.get("admin_error");
  const success = params.get("admin_success");
  const [message, setMessage] = useState<{ text: string; error: boolean } | null>(null);
  const [seen, setSeen] = useState<string | null>(null);
  const text = error ?? success;
  const key = text ? `${error ? "error" : "success"}:${text}` : null;

  // Adjust state while rendering (not in an effect) when a new notice
  // arrives; clearing `seen` lets the same message show again next time.
  if (key !== seen) {
    setSeen(key);
    if (key && text) setMessage({ text, error: Boolean(error) });
  }

  useEffect(() => {
    if (!key) return;
    const next = new URLSearchParams(window.location.search);
    next.delete("admin_error");
    next.delete("admin_success");
    const query = next.toString();
    window.history.replaceState(null, "", `${window.location.pathname}${query ? `?${query}` : ""}`);
  }, [key]);

  useEffect(() => {
    if (!message || message.error) return;
    const timer = window.setTimeout(() => setMessage(null), 5000);
    return () => window.clearTimeout(timer);
  }, [message]);

  return (
    <div className="toast-region" aria-live="polite">
      {message ? (
        <div className={`toast${message.error ? " is-error" : ""}`} role={message.error ? "alert" : "status"}>
          {message.error ? <CircleAlert size={17} /> : <CheckCircle2 size={17} />}
          <p>{message.text}</p>
          <button type="button" onClick={() => setMessage(null)}>Dismiss</button>
        </div>
      ) : null}
    </div>
  );
}

// Uncontrolled input + debounced URL update: typing never re-renders the page,
// and only the settled query reaches the server.
export function SearchField({
  param = "q",
  placeholder,
  label,
  resetParams = ["after"],
}: {
  param?: string;
  placeholder: string;
  label: string;
  resetParams?: string[];
}) {
  const router = useRouter();
  const pathname = usePathname();
  const params = useSearchParams();
  const [pending, startTransition] = useTransition();
  const timer = useRef<number | undefined>(undefined);
  const initial = params.get(param) ?? "";
  const lastSent = useRef(initial);

  useEffect(() => () => window.clearTimeout(timer.current), []);

  const push = (raw: string) => {
    const value = raw.trim();
    if (value === lastSent.current) return;
    lastSent.current = value;
    const next = new URLSearchParams(params.toString());
    if (value) next.set(param, value);
    else next.delete(param);
    for (const key of resetParams) next.delete(key);
    const query = next.toString();
    startTransition(() => router.replace(`${pathname}${query ? `?${query}` : ""}`, { scroll: false }));
  };

  return (
    <form
      className="search"
      role="search"
      onSubmit={(event) => {
        event.preventDefault();
        window.clearTimeout(timer.current);
        push(String(new FormData(event.currentTarget).get(param) ?? ""));
      }}
    >
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true"><circle cx="11" cy="11" r="7" /><path d="m20 20-3.5-3.5" /></svg>
      <label className="sr-only" htmlFor={`search-${param}`}>{label}</label>
      <input
        id={`search-${param}`}
        name={param}
        className="input"
        defaultValue={initial}
        placeholder={placeholder}
        autoComplete="off"
        spellCheck={false}
        onChange={(event) => {
          const value = event.currentTarget.value;
          window.clearTimeout(timer.current);
          timer.current = window.setTimeout(() => push(value), 350);
        }}
      />
      {pending ? <span className="spinner" aria-label="Searching" /> : null}
    </form>
  );
}

// datetime-local has no zone. Send the operator's local wall time as an
// absolute ISO instant so a campaign goes out when they meant it to.
export function LocalDateTimeInput({ name, label, defaultOffsetMinutes = 10 }: {
  name: string;
  label: string;
  defaultOffsetMinutes?: number;
}) {
  const localRef = useRef<HTMLInputElement>(null);
  const isoRef = useRef<HTMLInputElement>(null);
  const zoneRef = useRef<HTMLElement>(null);

  const sync = (value: string) => {
    if (isoRef.current) isoRef.current.value = value ? new Date(value).toISOString() : "";
  };

  // The default depends on the viewer's clock and zone, which the server
  // cannot know, so it is written straight into the inputs after mount.
  useEffect(() => {
    const start = new Date(Date.now() + defaultOffsetMinutes * 60_000);
    start.setSeconds(0, 0);
    const pad = (n: number) => String(n).padStart(2, "0");
    const value = `${start.getFullYear()}-${pad(start.getMonth() + 1)}-${pad(start.getDate())}T${pad(start.getHours())}:${pad(start.getMinutes())}`;
    if (localRef.current && !localRef.current.value) localRef.current.value = value;
    sync(localRef.current?.value ?? value);
    if (zoneRef.current) zoneRef.current.textContent = `Your time zone: ${Intl.DateTimeFormat().resolvedOptions().timeZone}`;
  }, [defaultOffsetMinutes]);

  return (
    <label className="field">
      {label}
      <input ref={localRef} type="datetime-local" className="input" required onChange={(event) => sync(event.currentTarget.value)} />
      <input ref={isoRef} type="hidden" name={name} />
      <small ref={zoneRef}>{" "}</small>
    </label>
  );
}

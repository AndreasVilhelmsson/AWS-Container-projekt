import { useCallback, useEffect, useState } from "react";
import { createMessage, listMessages, type Message } from "../api/client";

export function useMessages() {
  const [items, setItems] = useState<Message[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await listMessages();
      setItems(data.sort((a, b) => b.createdAt - a.createdAt));
    } catch (error: unknown) {
      const errorMessage =
        error instanceof Error ? error.message : "Failed to load messages";
      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  }, []);

  const add = useCallback(
    async (name: string, message: string) => {
      if (!name.trim() || !message.trim()) return;
      setLoading(true);
      setError(null);
      try {
        await createMessage({ name: name.trim(), message: message.trim() });
        await refresh();
      } catch (error: unknown) {
        const errorMessage =
          error instanceof Error ? error.message : "Failed to send message";
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    },
    [refresh]
  );

  useEffect(() => {
    void refresh();
  }, [refresh]);

  return { items, loading, error, add, refresh };
}

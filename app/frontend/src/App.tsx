import { useEffect, useState } from "react";
import { listMessages, createMessage, type Message } from "./api/client";
import { MessageForm } from "./components/MessageForm/MessageForm";
import { MessageList } from "./components/MessageList/MessageList";
import "./styles/app.scss";

export default function App() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    listMessages()
      .then(setMessages)
      .catch((error: unknown) => {
        const errorMessage =
          error instanceof Error ? error.message : "Failed to load";
        setError(errorMessage);
      });
  }, []);

  const handleSubmit = async (name: string, message: string) => {
    setLoading(true);
    setError(null);
    try {
      await createMessage({ name, message });
      setMessages(await listMessages());
    } catch (error: unknown) {
      const errorMessage =
        error instanceof Error ? error.message : "Failed to send";
      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="container">
      <h1 className="header">Serverless Contact Form</h1>
      <div className="panel">
        <MessageForm onSubmit={handleSubmit} disabled={loading} />
        {error && <p className="error">{error}</p>}
        {loading && <div className="spinner" />}
        <hr className="hr" />
        <h2>Messages</h2>
        <MessageList items={messages} />
      </div>
    </div>
  );
}

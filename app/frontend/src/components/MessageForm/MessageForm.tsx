import { useState } from "react";
import styles from "./MessageForm.module.scss";

export function MessageForm({
  onSubmit,
  disabled,
}: {
  onSubmit: (name: string, message: string) => void;
  disabled?: boolean;
}) {
  const [name, setName] = useState("");
  const [message, setMessage] = useState("");

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        if (!name.trim() || !message.trim()) return;
        onSubmit(name.trim(), message.trim());
        setMessage("");
      }}
      className={styles.form}
    >
      <input
        className={styles.input}
        placeholder="Name"
        value={name}
        onChange={(e) => setName(e.target.value)}
        disabled={disabled}
      />
      <input
        className={styles.input}
        placeholder="Message"
        value={message}
        onChange={(e) => setMessage(e.target.value)}
        disabled={disabled}
      />
      <button
        type="submit"
        className={styles.btn}
        disabled={disabled || !name || !message}
      >
        Send
      </button>
    </form>
  );
}

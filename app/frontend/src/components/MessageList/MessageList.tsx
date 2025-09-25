import type { Message } from "../../api/client";
import styles from "./MessageList.module.scss";
export function MessageList({ items }: { items: Message[] }) {
  if (!items.length) return <p className={styles.muted}>No messages yet.</p>;

  return (
    <ul className={styles.list}>
      {items.map((m) => (
        <li className={styles.item} key={m.id}>
          <b>{m.name}</b>: {m.message}{" "}
          <small className={styles.meta}>
            ({new Date(m.createdAt).toLocaleString()})
          </small>
        </li>
      ))}
    </ul>
  );
}

import axios from "axios";

export type Message = {
  id: string;
  name: string;
  message: string;
  createdAt: number;
};

const API = import.meta.env.VITE_API_BASE ?? "http://localhost:3000";

export async function listMessages(): Promise<Message[]> {
  const { data } = await axios.get<Message[]>(`${API}/messages`);
  return data;
}

export async function createMessage(payload: {
  name: string;
  message: string;
}): Promise<Message> {
  const { data } = await axios.post<Message>(`${API}/messages`, payload, {
    headers: { "Content-Type": "application/json" },
  });
  return data;
}

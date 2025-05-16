// app/src/lib/ws.ts
'use client';

export interface WSMessage {
    blockNumber: number;
    payload: { id: string };
}

let socket: WebSocket | null = null;
const subscribers = new Set<(msg: WSMessage) => void>();

function ensureSocket() {
    if (socket) return;

    const wsUrl = process.env.NEXT_PUBLIC_WS_URL || 'ws://localhost:3001/ws';
    socket = new WebSocket(wsUrl);

    socket.onopen = () => console.log('WebSocket connected');
    socket.onclose = () => {
        console.log('WebSocket disconnected');
        socket = null;
    };
    socket.onerror = (err) => console.error('WebSocket error', err);

    socket.onmessage = (evt) => {
        let msg: WSMessage;
        try {
            msg = JSON.parse(evt.data);
        } catch {
            console.error('Invalid WS payload', evt.data);
            return;
        }
        subscribers.forEach((fn) => {
            try {
                fn(msg);
            } catch (e) {
                console.error('subscriber error', e);
            }
        });
    };
}

/**
 * Subscribe to WS events. Returns an unsubscribe function.
 */
export function connectWS(cb: (msg: WSMessage) => void): {
    unsubscribe: () => void;
} {
    subscribers.add(cb);
    ensureSocket();
    return {
        unsubscribe() {
            subscribers.delete(cb);
            // if nobody’s left listening, tear down the socket
            if (subscribers.size === 0 && socket) {
                socket.close();
                socket = null;
            }
        },
    };
}

package main

import (
	"sync"
	"github.com/gorilla/websocket"
)

type Hub struct {
	clients map[*websocket.Conn]struct{}
	lock    sync.RWMutex
}

func NewHub() *Hub { 
	return &Hub{clients: make(map[*websocket.Conn]struct{})} 
}

func (h *Hub) Add(c *websocket.Conn) {
	h.lock.Lock()
	defer h.lock.Unlock()
	h.clients[c] = struct{}{}
}

func (h *Hub) Remove(c *websocket.Conn) {
	h.lock.Lock()
	defer h.lock.Unlock()
	delete(h.clients, c)
}

func (h *Hub) Broadcast(b []byte) {
	h.lock.RLock()
	defer h.lock.RUnlock()
	for c := range h.clients {
		_ = c.WriteMessage(websocket.TextMessage, b)
	}
}
package room

import (
	"sync"
)

type Connection interface {
	WriteJSON(v interface{}) error
	ReadJSON(v interface{}) error
	Close() error
}

type Client struct {
	ID       string
	Username string
	Room     *Room
	Conn     Connection
	Send     chan WSMessage
	mu       sync.Mutex
	closed   bool
}

func NewClient(id, username string, room *Room, conn Connection) *Client {
	return &Client{
		ID:       id,
		Username: username,
		Room:     room,
		Conn:     conn,
		Send:     make(chan WSMessage, 64),
	}
}

func (c *Client) WritePump() {
	for msg := range c.Send {
		c.mu.Lock()
		if c.closed {
			c.mu.Unlock()
			return
		}
		err := c.Conn.WriteJSON(msg)
		c.mu.Unlock()
		if err != nil {
			break
		}
	}
}

func (c *Client) Close() {
	c.mu.Lock()
	defer c.mu.Unlock()
	if !c.closed {
		c.closed = true
		close(c.Send)
		if c.Conn != nil {
			_ = c.Conn.Close()
		}
	}
}

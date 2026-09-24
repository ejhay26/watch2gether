package room

import (
	"sync"
	"testing"
	"time"
)

type MockConn struct {
	receivedMessages []WSMessage
	mu               sync.Mutex
	closed           bool
}

func (m *MockConn) WriteJSON(v interface{}) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if msg, ok := v.(WSMessage); ok {
		m.receivedMessages = append(m.receivedMessages, msg)
	}
	return nil
}

func (m *MockConn) ReadJSON(v interface{}) error {
	return nil
}

func (m *MockConn) Close() error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.closed = true
	return nil
}

func (m *MockConn) GetMessages() []WSMessage {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := make([]WSMessage, len(m.receivedMessages))
	copy(out, m.receivedMessages)
	return out
}

func TestRoomLifecycleAndSync(t *testing.T) {
	hub := NewHub()

	// 1. Create Room
	room := hub.CreateRoom("host-1", "demo-sintel", "Sintel 4K", "https://test.m3u8", "ep1", nil)
	if len(room.ID) != 6 {
		t.Fatalf("Expected 6-char room code, got %s", room.ID)
	}

	// 2. Client A (Host) joins
	connA := &MockConn{}
	clientA := NewClient("user-a", "Alice", room, connA)
	go clientA.WritePump()
	room.Register(clientA)

	// 3. Client B joins
	connB := &MockConn{}
	clientB := NewClient("user-b", "Bob", room, connB)
	go clientB.WritePump()
	room.Register(clientB)

	// Allow message delivery
	time.Sleep(50 * time.Millisecond)

	// Verify Bob received initial ROOM_STATE
	msgsB := connB.GetMessages()
	if len(msgsB) == 0 || msgsB[0].Type != EventRoomState {
		t.Fatalf("Expected Bob to receive ROOM_STATE on join")
	}

	// 4. Alice (Host) clicks PLAY at position 10.0
	room.HandleMessage(clientA, WSMessage{
		Type:     EventPlay,
		Position: 10.0,
	})

	time.Sleep(50 * time.Millisecond)

	// Verify both Alice and Bob received PLAY event with execute_at_ms in the future
	msgsB = connB.GetMessages()
	foundPlay := false
	for _, m := range msgsB {
		if m.Type == EventPlay {
			foundPlay = true
			if m.Position != 10.0 {
				t.Errorf("Expected play position 10.0, got %f", m.Position)
			}
			if m.ExecuteAtMS <= time.Now().UnixMilli() {
				t.Errorf("Expected execute_at_ms to be in the future")
			}
		}
	}
	if !foundPlay {
		t.Errorf("Bob never received PLAY event")
	}

	// 5. Bob sends chat message
	room.HandleMessage(clientB, WSMessage{
		Type:    EventChat,
		Message: "Watch together is awesome!",
	})

	time.Sleep(50 * time.Millisecond)

	// Verify Alice received Bob's chat
	msgsA := connA.GetMessages()
	foundChat := false
	for _, m := range msgsA {
		if m.Type == EventChat && m.Message == "Watch together is awesome!" {
			foundChat = true
			if m.User == nil || m.User.Username != "Bob" {
				t.Errorf("Expected chat author to be Bob")
			}
		}
	}
	if !foundChat {
		t.Errorf("Alice never received Bob's chat message")
	}

	// 6. Seek and Pause
	room.HandleMessage(clientA, WSMessage{
		Type:     EventSeek,
		Position: 120.5,
	})
	room.HandleMessage(clientA, WSMessage{
		Type:     EventPause,
		Position: 120.5,
	})

	time.Sleep(50 * time.Millisecond)
	if room.IsPlaying {
		t.Errorf("Room should be paused")
	}
	if room.CurrentPosition() != 120.5 {
		t.Errorf("Expected playback position 120.5, got %f", room.CurrentPosition())
	}

	// 7. Alice leaves -> Bob becomes Host
	room.Unregister(clientA)
	if room.HostID != "user-b" {
		t.Errorf("Expected Bob (user-b) to be promoted to Host, got %s", room.HostID)
	}

	// 8. Bob leaves -> Room is destroyed
	room.Unregister(clientB)
	time.Sleep(20 * time.Millisecond)
	if hub.RoomCount() != 0 {
		t.Errorf("Expected 0 rooms after all users leave, got %d", hub.RoomCount())
	}
}

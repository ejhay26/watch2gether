package subtitle

import (
	"context"
	"testing"
)

func TestSubtitleEngine(t *testing.T) {
	se := NewSubtitleEngine()
	subs, err := se.GetSubtitles(context.Background(), "test-id", "Night of the Living Dead")
	if err != nil {
		t.Fatalf("GetSubtitles failed: %v", err)
	}

	if len(subs) < 2 {
		t.Fatalf("Expected at least 2 subtitle tracks, got %d", len(subs))
	}

	hasEnglish := false
	for _, s := range subs {
		if s.Lang == "English [CC]" {
			hasEnglish = true
			break
		}
	}

	if !hasEnglish {
		t.Errorf("Expected English [CC] subtitle track")
	}
}

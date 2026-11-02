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

func TestSearchSubtitles(t *testing.T) {
	se := NewSubtitleEngine()
	ctx := context.Background()

	subs, err := se.SearchSubtitles(ctx, "The Paramedic", "", "")
	if err != nil {
		t.Fatalf("SearchSubtitles failed: %v", err)
	}
	if len(subs) == 0 {
		t.Fatalf("Expected at least 1 subtitle track for 'The Paramedic'")
	}
	t.Logf("The Paramedic returned %d subtitles", len(subs))
	for _, s := range subs {
		t.Logf("Subtitle: %s -> %s", s.Lang, s.URL)
	}

	kimiSubs, err := se.SearchSubtitles(ctx, "Kimi", "", "")
	if err != nil {
		t.Fatalf("SearchSubtitles for Kimi failed: %v", err)
	}
	if len(kimiSubs) == 0 {
		t.Fatalf("Expected at least 1 subtitle track for 'Kimi'")
	}
	t.Logf("Kimi returned %d subtitles", len(kimiSubs))
}

